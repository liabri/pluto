//! # Auriel Engine: RAG Pipeline
//!
//! The Auriel Engine acts as an intelligent middleware proxy that enables
//! Retrieval-Augmented Generation (RAG). It intercepts standard chat requests, enriches
//! them with verified local context, and streams the resulting reasoning back to the user.
//!
//! - **Axum (Orchestrator):** Manages high-concurrency requests and lifecycle management.
//! - **Qdrant (The Librarian):** Performs low-latency, gRPC-based vector similarity searches.
//! - **Ollama (The Processor):** Provides both the Embedding model (for vectorization)
//!   and the LLM (for reasoning/generation).
//!
//! ## The RAG Lifecycle
//! | Step | Action | Description |
//! | :--- | :--- | :--- |
//! | **1. Reception** | Gatekeeping | Axum receives the request and spawns an async handler. |
//! | **2. Extraction** | Parsing | The engine isolates the user's latest prompt from the history. |
//! | **3. Embedding** | Translation | Ollama converts the prompt into a semantic vector. |
//! | **4. Retrieval** | Search | Qdrant finds the 3 most relevant academic text chunks. |
//! | **5. Synthesis** | Augmentation | Context is injected as a `system` prompt to ground the LLM. |
//! | **6. Inference** | Generation | The augmented request is sent to the LLM for reasoning. |
//! | **7. Streaming** | Delivery | Token chunks are proxied directly back to the client. |

// -----------------------------------------------------------------------------
// DEVELOPMENT ROADMAP: Features to Implement
// -----------------------------------------------------------------------------
/*
    [ ] Query Reformulation: Rewrite follow-up questions to include context
        before performing vector search.
    [ ] Hybrid Search: Combine BM25 (Keyword) + Vector search in Qdrant
        for higher precision on specific academic terms.
    [ ] Intent Routing: Use a small model to classify if a query needs
        a database search or a direct LLM response.
    [ ] Metadata Filtering: Allow users to specify a 'source' (e.g., 'lingwistika')
        to narrow the search scope in Qdrant.
    [ ] Source Citations: Inject metadata (page numbers/doc names) into
        the system prompt and force the LLM to cite its references.
    [ ] Evaluator Loop: Implement a 'Judge' step to compare the retrieved
        chunks against the final answer to detect poor retrieval.
*/

use axum::{ body::Body,
    extract::State,
    http::{HeaderMap, StatusCode},
    response::IntoResponse,
    routing::post,
    Json, Router,
};
use qdrant_client::{qdrant::QueryPointsBuilder, Qdrant};
use reqwest::Client as HttpClient;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, net::SocketAddr, sync::Arc};
use tokio::sync::Mutex;

// -----------------------------------------------------------------------------
// Type Definitions
// -----------------------------------------------------------------------------

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct Message {
    pub role: String,
    pub content: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct ChatRequest {
    pub model: String,
    pub messages: Vec<Message>,
    pub stream: Option<bool>,
}

#[derive(Serialize)]
struct EmbedRequest {
    pub model: String,
    pub prompt: String,
}

#[derive(Deserialize)]
struct EmbedResponse {
    pub embedding: Vec<f32>,
}

// Global Application State
struct AppState {
    http_client: HttpClient,
    qdrant_client: Qdrant,
    // Optional: Memory map to track chat histories by user/session ID
    // chat_sessions: Mutex<HashMap<String, Vec<Message>>>,
}

// -----------------------------------------------------------------------------
// Main Entry Point
// -----------------------------------------------------------------------------

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("[Auriel Engine] Booting high-performance Rust RAG server...");

    // 1. Initialize the ultra-fast gRPC client for Qdrant (Port 6334)
    let qdrant_client = Qdrant::from_url("http://127.0.0.1:6334").build()?;

    // 2. Initialize a shared HTTP client with connection pooling for Ollama
    let http_client = HttpClient::new();

    let state = Arc::new(AppState {
        http_client,
        qdrant_client,
    });

    // 3. Define our OpenAI-compatible API route
    let app = Router::new()
        .route("/v1/chat/completions", post(handle_rag_chat))
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], 8000));
    println!("[Auriel Engine] Listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

// -----------------------------------------------------------------------------
// The RAG Pipeline Handler
// -----------------------------------------------------------------------------

async fn handle_rag_chat(
    State(state): State<Arc<AppState>>,
    Json(mut payload): Json<ChatRequest>,
) -> Result<impl IntoResponse, (StatusCode, String)> {

    // 1. Extract the user's latest question
    let user_prompt = payload
        .messages
        .last()
        .map(|m| m.content.clone())
        .ok_or((StatusCode::BAD_REQUEST, "Empty messages list".into()))?;

    // 2. Get vector embedding from Ollama
    let embed_req = EmbedRequest {
        model: "nomic-embed-text".to_string(),
        prompt: user_prompt.clone(),
    };

    let embed_res: EmbedResponse = state
        .http_client
        .post("http://127.0.0.1:11434/api/embeddings")
        .json(&embed_req)
        .send()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .json()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    // 3. High-Speed gRPC Query to Qdrant Vector Database
    let search_result = state
        .qdrant_client
        .query(
            QueryPointsBuilder::new("lingwistika")
                .query(embed_res.embedding)
                .limit(3)
                .with_payload(true),
        )
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    // 4. Aggregate Text Chunks
    let mut context_text = String::new();
    for point in search_result.result {
        if let Some(payload_map) = point.payload {
            // Assuming your ingestion script puts the PDF chunk in a "text" field
            if let Some(text_val) = payload_map.get("text") {
                if let Some(text) = text_val.as_str() {
                    context_text.push_str(text);
                    context_text.push_str("\n\n---\n\n");
                }
            }
        }
    }

    // 5. Augment the System Prompt
    let system_prompt = format!(
        "You are an expert linguist. Use the following academic context to answer the user's question accurately.\n\nContext:\n{}",
        context_text
    );

    // Inject the system prompt at the very beginning of the chat history
    payload.messages.insert(
        0,
        Message {
            role: "system".to_string(),
            content: system_prompt,
        },
    );

    // 6. Forward augmented payload to Ollama for generation
    let ollama_res = state
        .http_client
        .post("http://127.0.0.1:11434/v1/chat/completions")
        .json(&payload)
        .send()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    // 7. Transparently Stream Output Back to Zed
    // We capture Ollama's HTTP headers and stream the raw body directly to the client
    let mut headers = HeaderMap::new();
    for (key, value) in ollama_res.headers() {
        headers.insert(key.clone(), value.clone());
    }

    let status = ollama_res.status();
    let body = Body::from_stream(ollama_res.bytes_stream());

    Ok((status, headers, body))
}
