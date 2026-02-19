package main

import("log"; "io"; "net"; "os")

func OpenBridge() {
	socketPath := "/bridge/rcon.sock"
	tcpAddr := "127.0.0.1:25575"

	_ = os.Remove(socketPath)
	listener, err := net.Listen("unix", socketPath)
	if err != nil { log.Fatalf("Proxy Listen Error: %v", err) }
	defer listener.Close()

	log.Printf("Bridge listening on %s -> forwarding to %s", socketPath, tcpAddr)
	for {
		// accept connection from outside
		uConn, err := listener.Accept()
		if err != nil { log.Printf("Unix accept error: %v", err); continue }
		
		log.Println("Outside client connected. Dialing Minecraft TCP RCON...")

		// dial the local mc tcp rcon port
		tConn, err := net.Dial("tcp", tcpAddr)
		if err != nil { log.Printf("TCP Dial Error (is Minecraft running?): %v", err); uConn.Close(); continue }

		// handle the data transfer in a backgroudn goroutine
		go func(u, t net.Conn) {
			defer u.Close()
			defer t.Close()
		
			log.Println("Connection bridged. Data flowing...")

			// copy data in both directions, we use a channel to wait until at least on side closes the conn
			done := make(chan struct{}, 2)

			// outside client -> mc
			go func() { io.Copy(t, u); done <- struct{}{} }()

			// mc -> outside client
			go func() { io.Copy(u, t); done <- struct{}{} }()
		
			// wait for one side to close
			<-done
			log.Println("Connection closed.")
		}(uConn, tConn)
	}
}
