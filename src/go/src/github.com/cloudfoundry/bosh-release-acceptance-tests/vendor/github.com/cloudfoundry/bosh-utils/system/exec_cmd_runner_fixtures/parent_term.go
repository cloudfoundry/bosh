package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"syscall"
)

func main() {
	fmt.Printf("parent_pid=%d\n", os.Getpid())

	sigTermCh := make(chan os.Signal, 1)
	signal.Notify(sigTermCh, syscall.SIGTERM)

	go func() {
		<-sigTermCh
		fmt.Printf("Parent received SIGTERM")
		os.Exit(13)
	}()

	// Compiled by tests
	cmd := exec.Command(filepath.Join(filepath.Dir(os.Args[0]), "child_term"))
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()

	// Keep on running even if child dies
	select {}
}
