package main

// to do: 
// output/*.html need to ne able to update, browser caching causes issues with this
// nice file explorer

import("bytes"; "log"; "fmt"; "io"; "html/template"; "time"; "os"; "os/exec"; "net/http"; "net/http/httputil"; "net/url"; "strings"; "path/filepath")

const (
	SWS_ADDR = "http://localhost:8081" // the server at /public
	DATA_DIR = "/docs/" // mounted volume with docs
)

// pull the proxy prefix from the environment (e.g. "/editor")
var SITE_ROOT = os.Getenv("SITE_ROOT")

func main() {
	entries, err := os.ReadDir("/public/output")
	if err != nil { panic(err) }
	for _, entry := range entries { fmt.Println(entry.Name()) }

	startCodeMirror()

	target, _ := url.Parse(SWS_ADDR)
	proxy := httputil.NewSingleHostReverseProxy(target)

	// all traffic must pass through here
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		ext := filepath.Ext(r.URL.Path)
		log.Printf("FOR PATH: %s, THE EXT IS: %s", r.URL.Path, ext)
	
		// api calls, /load or /save. this is exclusively to read/write respectively files in /data	
		if strings.Contains(r.URL.Path, "/api/") { handleAPI(w,r); return }

		// editor ui, only shown when a file is open (that we want to edit) a.k.a. when path has query "?file=<filename>" 
		if r.URL.Query().Get("file") != "" { serveEditorUI(w, r); return }

		// custom file explorer
		if r.URL.Path==SITE_ROOT { log.Println("BOOOOO!!!! !SERVING EXPLORRERRRR!!"); serveFileExplorer(w, r); return }

		// normalise path by striping prefix (e.g. editor/js/bundle.js -> /js/bundle.js)
		if SITE_ROOT != "" && strings.HasPrefix(r.URL.Path, SITE_ROOT) {
			r.URL.Path = strings.TrimPrefix(r.URL.Path, SITE_ROOT)
			if r.URL.Path == "" { r.URL.Path = "/" } // ensures empty paths resolve to SWS root
		}

		// proxy the remaining requests through to the SWS server
		proxy.ServeHTTP(w, r)

	})

	log.Println("Orchestrator server active on port 8080")
	if err := http.ListenAndServe(":8080", nil); err != nil { log.Fatalf("Server failed: %v", err) }	
}

// --- serve file explorer ---
func serveFileExplorer(w http.ResponseWriter, r *http.Request) {
	// define data structures to pass into html
	type FileItem struct {
		Name		string
		EscapedName	string
		ModTime		string
	}
	type PageData struct {
		DataDir string
		Files 	[]FileItem
	}

	// populate the data
	entries, err := os.ReadDir(DATA_DIR)
	if err != nil { http.Error(w, "Failed to read data directory", http.StatusInternalServerError); return }

	var data PageData
	data.DataDir = DATA_DIR
	for _, entry := range entries {
		if !entry.IsDir() {
			info, err := entry.Info()
			dateStr := "Unknown date"
			if err == nil { dateStr = info.ModTime().Format("Jan 02, 2006 15:04") }

			data.Files = append(data.Files, FileItem {
				Name:		entry.Name(),
				EscapedName:	url.QueryEscape(entry.Name()),
				ModTime:	dateStr,
			})
		}
	}

	// write to html template using {{.Tags}}
	tmpl, err := template.ParseFiles("/public/explorer.html")
	if err != nil { log.Printf("Explorer template error: %v", err); http.Error(w, "Explorer template error", http.StatusInternalServerError); return }

	w.Header().Set("Content-Type", "text/html")
	if err := tmpl.Execute(w, data); err != nil { log.Printf("Error executing template: %v", err) }	
}

// --- serve ui (possibly w/ preview injection) ---
func serveEditorUI(w http.ResponseWriter, r *http.Request) {
	// fetch index.html template from sws and inject preview if needed
//	resp, err := http.Get(SWS_ADDR + "/index.html")
//	if err != nil { http.Error(w, "HTML template unreachable", http.StatusBadGateway); return }
//	defer resp.Body.Close()
//	body, err := io.ReadAll(resp.Body)

	body, err := os.ReadFile("/public/index.html")
	if err != nil { http.Error(w, "Failed to read HTML template", http.StatusInternalServerError); return }

	// build base tag for index.html
	prefix := r.URL.Path
	if !strings.HasSuffix(prefix, "/") { prefix += "/" }
	baseTag := fmt.Sprintf(`<base href="%s">`, prefix)

	// editor html w/o preview pane
	ui := `<div id="editor" style="height:100vh;"></div>`

	// editor html w/ preview pane
	filename := r.URL.Query().Get("file")
	hasPreview := strings.HasSuffix(filename, ".qmd")
	if hasPreview {
		// need to make option to preview pdf too
		previewFile := filepath.Join("output", strings.TrimSuffix(filename, ".qmd") + ".html")
		ui = fmt.Sprintf(`
			<div style="display:flex; height:100vh; width:100vw;">
				<div id="editor" style="flex:1; border-right:2px solid #333; overflow: auto;"></div>
				<iframe src="%s" style="flex:1; border:none;"></iframe>
			</div>`, previewFile)
	}
	
	// replace the placeholders in index.html with our base tag and dynamic UI
	out := bytes.Replace(body, []byte("{{.BaseTag}}"), []byte(baseTag), 1) 
	out = bytes.Replace(out, []byte("{{.EditorUI}}"), []byte(ui), 1)

	w.Header().Set("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
	w.Header().Set("Pragma", "no-cache")
	w.Header().Set("Expires", "0")
	w.Header().Set("Content-Type", "text/html")
	w.Write(out)

}

func handleAPI(w http.ResponseWriter, r *http.Request) {
	filename := r.URL.Query().Get("file")
	if filename == "" { http.Error(w, "Filename required", 400); return }
	path := DATA_DIR + filename

	switch {

	// read
	case strings.HasSuffix(r.URL.Path, "/api/load"):
		content, err := os.ReadFile(path)
		if err != nil { http.Error(w, "Read error", 404); return }
		w.Write(content)

	// write
	case strings.HasSuffix(r.URL.Path, "/api/save"):
		if r.Method != http.MethodPost { http.Error(w, "Method not allowed", 405); return }
		body, _ := io.ReadAll(r.Body)
		if err := os.WriteFile(path, body, 0644); err != nil { http.Error(w, "Write error", 500); return }
		fmt.Fprint(w, "Saved")

	default:
		http.NotFound(w, r)

	}
}

func startCodeMirror() {
	cmd := exec.Command("/sws",
		"--port", "8081",
		"--root", "/public",
		"--log-level", "info",
		"--directory-listing", "true",
	)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	fmt.Println("Starting SWS on internal port 8080...")
	if err := cmd.Start(); err != nil { log.Fatalf("Failed to start SWS: %v", err) }

	go func() {
		if err := cmd.Wait(); err != nil {
			log.Printf("SWS exited with error: %v", err)
		}
	}()

	time.Sleep(500 * time.Millisecond)
}
