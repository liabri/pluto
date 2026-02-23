package main

import("log"; "fmt"; "os"; "os/exec"; "strings")

func main() {
	repo := os.Getenv("BORG_REPO")
	destBase := "/srv/minecraft/"		// the named volume mount point 
	worldPath := "/srv/minecraft/world"	// the specific target

	if repo == "" { log.Fatal("BORG_REPO environment variable has not been defined! Aborting...") }

	fmt.Println("--- Pre-Restore Validation ---")
	fmt.Printf("Repo: %s\nTarget: %s\n", repo, worldPath)

	// ensure the destination base exists
	info, err := os.Stat(destBase)
	if os.IsNotExist(err) { log.Fatalf("CRITICAL: There is no minecraft working tree at %s. Ensure your volume is mounted correctly.", destBase) }
	if !info.IsDir() { log.Fatalf("CRITICAL: %s exists but is not a directory!", destBase) } 
	fmt.Printf("Directory successfully found at %s", destBase)

	// check if world already exists
	if _, err := os.Stat(worldPath); err == nil {
		fmt.Println("World folder already exists. Skipping restore to avoid overwriting current data.")
		os.Exit(1)
	}
	fmt.Printf("World does not already exist at %s", worldPath)

	// find latest archive name
	listCmd := exec.Command("/usr/bin/borg", "list", "--last", "1", "--format", "{archive}", repo)
	nameBytes, err := listCmd.CombinedOutput()
	if err != nil { log.Fatalf("Failed to list archives: %v\nOutput: %s", err, string(nameBytes)) }
	archiveName := strings.TrimSpace(string(nameBytes))
	if archiveName == "" { log.Fatal("No archives found in the repository. Nothing to restore.") }
	fmt.Printf("Found archive '%s'! Extracting into %s\n", archiveName, worldPath) 
	
	// extract archive
	extractCmd := exec.Command("/usr/bin/borg", "extract", "--strip-components", "1", repo+"::"+archiveName)
	extractCmd.Dir = destBase // run from volume root

	output, err := extractCmd.CombinedOutput()
	if err != nil { log.Fatalf("Borg extract failed!\n Error: %v\n Output: %s", err, string(output)) }
	fmt.Println("Pull Successful!")
}
