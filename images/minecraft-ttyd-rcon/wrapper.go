package main

import("bufio"; "fmt"; "io"; "os"; "strings"; "time"; "github.com/gorcon/rcon"; "net")

func main() {
	logPath := "/srv/minecraft-server/logs/latest.log"
	rconPass := os.Getenv("RCON_PASSWORD")
	socketPath := "/bridge/rcon.sock"
	
	// wait for "Done" message in latest.log, indicating the server is done loading
	fmt.Println("Waiting for Minecraft server to start...")
	for {
		if data, err := os.ReadFile(logPath); err == nil && strings.Contains(string(data), "Done (") { break }
		time.Sleep(2 * time.Second)
	}

	// tail logs to Stdout in a goroutine
	go func() {
		f, _ := os.Open(logPath)
		f.Seek(0, io.SeekEnd)
		r := bufio.NewReader(f)
		for {
			line, _ := r.ReadString('\n')
			if line != "" { fmt.Print(line) } else { time.Sleep(500 * time.Millisecond) }
		}
	}()

	// persistent rcon session via unix socket
	for {
		netConn, err := net.Dial("unix", socketPath)
		if err != nil {
             		fmt.Printf("Socket not ready at %s: %v. Retrying...\n", socketPath, err)
			time.Sleep(5 * time.Second)
			continue
		}

		conn, err := rcon.Open(netConn, rconPass)
		if err != nil {
             		fmt.Printf("RCON Auth failed: %v.\n", err)
			time.Sleep(5 * time.Second)
			continue
		}

		fmt.Println("--- RCON CONNECTED ---")
		scanner := bufio.NewScanner(os.Stdin)
		for scanner.Scan() {
			resp, err := conn.Execute(scanner.Text())
			if err != nil { fmt.Println("Connections lost. Reconnecting..."); break }
			fmt.Println(resp)
		}
		conn.Close()
	}
}
