package main

import("log"; "fmt"; "os"; "os/exec"; "time"; "github.com/gorcon/rcon"; "net"; "path/filepath"; "strings")

func main() {
	repo := os.Getenv("BORG_REPO")
	if repo == "" { log.Fatal("BORG_REPO environment variable has not been defined! Aborting...") }

	// ensure repo is ready
	initBorg(repo)

	// establish connection
	conn, err := Connect()
	if err != nil { log.Fatal(err) }
	defer conn.Close()

	fmt.Println("--- [1/3] Freezing Minecraft World ---")
	resp1, err := conn.Execute("save-off")
	if err != nil { log.Fatalf("RCON Connection Error during 'save-off': %v", err) }
	fmt.Printf("RCON response [save-off]: %s\n", strings.TrimSpace(resp1))

	resp2, err := conn.Execute("save-all flush")
	if err != nil { log.Fatalf("RCON Connection Error during 'save-all flush': %v", err) }
	fmt.Printf("RCON response [save-all flush]: %s\n", strings.TrimSpace(resp2))

	time.Sleep(5 * time.Second)	

	fmt.Println("--- [2/3] Executing Borg ---")
	archive := fmt.Sprintf("%s::mc-%s", repo, time.Now().Format("2006-01-02"))
	cmd := exec.Command("/usr/bin/borg", "create", "--stats", archive, "/data")
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr

	// if error, continues to thaw the world
	if err := cmd.Run(); err != nil {
		fmt.Printf("Borg Error: %v\n", err)
	}

	fmt.Println("--- [3/3] Resuming World Saving ---")
	resp3, err := conn.Execute("save-on")
	if err != nil { log.Fatalf("RCON Connection Error during 'save-on': %v", err) }
	fmt.Printf("RCON response [save-on]: %s\n", strings.TrimSpace(resp3))

	
	fmt.Println("Backup Routine Finished")
}

func initBorg(repo string) {
	configPath := filepath.Join(repo, "config")
	if _, err := os.Stat(configPath); err == nil {
		fmt.Println("Borg repository already initialised")
		return
	}

	fmt.Println("--- Initialising Borg Repository ---")
	cmd := exec.Command("/usr/bin/borg", "init", "--encryption", "none", repo)

	// capture output in case of failure
	output, err := cmd.CombinedOutput()
	if err != nil { log.Fatalf("Failed to initialise Borg repo! Error: %v\nOutput: %s", err, string(output)) }
}

func Connect() (*rcon.Conn, error) {
	rconPass := os.Getenv("RCON_PASSWORD")
	socketPath := "/bridge/rcon.sock"
	
	// open raw connection
	netConn, err := net.Dial("unix", socketPath)
	if err != nil {
       		fmt.Errorf("Socket not ready at %s: %v. Aborting.", socketPath, err)
		os.Exit(1)
	}
	
	// wrap connection w/ RCON protocol
	conn, err := rcon.Open(netConn, rconPass)
	if err != nil {
		fmt.Errorf("RCON authentication failed: %v\n", err)
		os.Exit(1)
	}

	return conn, nil
}
