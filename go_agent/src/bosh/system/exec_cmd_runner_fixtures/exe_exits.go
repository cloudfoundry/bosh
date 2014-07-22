package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGKILL)

	go func() {
		for {
			switch <-sigCh {
			case syscall.SIGTERM:
				fmt.Printf("Exe received SIGTERM\n")
			case syscall.SIGKILL:
				fmt.Printf("Exe received SIGKILL\n")
			}
		}
	}()

	// Exit immediately
	os.Exit(0)
}
