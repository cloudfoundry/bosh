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

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGKILL)

	go func() {
		for {
			switch <-sigCh {
			case syscall.SIGTERM:
				fmt.Printf("Parent received SIGTERM\n")
			case syscall.SIGKILL:
				fmt.Printf("Parent received SIGKILL\n")
			}
		}
	}()

	// Compiled by tests
	cmd := exec.Command(filepath.Join(filepath.Dir(os.Args[0]), "child_ignore_term"))
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()

	// Keep on running even if child dies
	select {}
}
