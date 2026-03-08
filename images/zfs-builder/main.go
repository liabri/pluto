package main

import("bytes"; "log"; "fmt"; "io"; "time"; "os"; "os/exec"; "net/http"; "net/http/httputil"; "net/url"; "strings"; "path/filepath")

const (
	SWS_ADDR = "http://localhost:8081" // this server
	PREVIEW_ADDR = "http:/10.254.2.1:8080" // the preview server 
	DATA_DIR = "/data/" // mounted volume with docs
)

func main() {
	startCodeMirror()

	target, _ := url.Parse(SWS_ADDR)
	proxy := httputil.NewSingleHostReverseProxy(target)

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path
		ext := filepath.Ext(path)

		if strings.Contains(path, "/api/") { handleAPI(w,r); return}

		if ext == "" || ext == ".html" { serveUI(w, r);	return }

		// strip prefix (e.g. editor/js/bundle.js -> /js/bundle.js)
		segments := strings.Split(strings.Trim(path, "/"), "/")
		if len(segments) >=2 {
			r.URL.Path = "/" + strings.Join(segments[len(segments)-2:], "/")
		}
	
		// let sws handle js/css
		proxy.ServeHTTP(w, r)

	})

	log.Println("Orchestrator active on port 8080")
	if err := http.ListenAndServe(":8080", nil); err != nil { log.Fatalf("Server failed: %v", err) }	
}

// --- serve ui (possibly w/ preview server injection) ---
func serveUI(w http.ResponseWriter, r *http.Request) {
	// fetch index.html template from sws and inject preview if needed
	resp, err := http.Get(SWS_ADDR + "/index.html")
	if err != nil { http.Error(w, "HTML template unreachable", http.StatusBadGateway); return }
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil { http.Error(w, "Failed to read HTML template", http.StatusInternalServerError); return }

	// build base tag for index.html
	prefix := r.URL.Path
	if !strings.HasSuffix(prefix, "/") { prefix += "/" }
	baseTag := fmt.Sprintf(`<base href="%s">`, prefix)

	// editor html w/o preview pane
	filename := r.URL.Query().Get("file")
	ui := `<div id="editor" style="height:100vh;"></div>`

	// editor html w/ preview pane
	isQmd := strings.HasSuffix(r.URL.Query().Get("file"), ".qmd")
	if isQmd {
		previewFile := strings.TrimSuffix(filename, ".qmd") + ".html" // this assumes quarto renders filename.qmd to filename.html
		ui = fmt.Sprintf(`
			<div style="display:flex; height:100vh; width:100vw;">
				<div id="editor" style="flex:1; border-right:2px solid #333; overflow: auto;"></div>
				<iframe src="%s/%s" style="flex:1; border:none;"></iframe>
			</div>`, PREVIEW_ADDR, previewFile)
	}
	
	// replace the placeholder in index.html with our dynamic UI
	out := bytes.Replace(body, []byte("{{.BaseTag}}"), []byte(baseTag), 1) 
	out = bytes.Replace(out, []byte("{{.EditorUI}}"), []byte(ui), 1)

	w.Header().Set("Content-Type", "text/html")
	w.Write(out)

}

func handleAPI(w http.ResponseWriter, r *http.Request) {
	filename := r.URL.Query().Get("file")
	if filename == "" { http.Error(w, "Filename required", 400); return }
	path := DATA_DIR + filename

	switch {

	// read
	case strings.HasSuffix(r.URL.Path, "/api/load/"):
		content, err := os.ReadFile(path)
		if err != nil { http.Error(w, "Read error", 404); return }
		w.Write(content)

	// write
	case strings.HasSuffix(r.URL.Path, "/api/save/"):
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
