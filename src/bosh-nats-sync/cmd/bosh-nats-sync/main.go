package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"bosh-nats-sync/pkg/config"
	"bosh-nats-sync/pkg/runner"
)

func main() {
	configFile := flag.String("c", "", "configuration file")
	flag.StringVar(configFile, "config", "", "configuration file")
	flag.Parse()

	if *configFile == "" {
		fmt.Fprintf(os.Stderr, "Usage: bosh-nats-sync -c <config_file>\n")
		flag.PrintDefaults()
		os.Exit(1)
	}

	cfg, err := config.Load(*configFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading config: %s\n", err)
		os.Exit(1)
	}

	logger := config.NewLogger(cfg)

	r := runner.New(cfg, logger)

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigCh
		r.Stop()
	}()

	r.Run()
}
