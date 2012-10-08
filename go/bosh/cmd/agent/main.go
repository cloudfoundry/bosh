package main

import (
	"bosh/agent"
	"fmt"
	log "github.com/cihub/seelog"
	"os"
)

func main() {
	defer log.Flush()

	config, err := agent.LoadConfig()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Invalid configuration: %s\n", err.Error())
		os.Exit(1)
	}

	server, err := agent.NewServer(config)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error starting agent: %s\n", err.Error())
		os.Exit(1)
	}

	server.Start()
}
