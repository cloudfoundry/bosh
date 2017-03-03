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

	done := make(chan struct{})
	var exitStatus int
	go func() {
		defer close(done)
		sig := <-sigCh
		switch s := sig.String(); s {
		case "SIGTERM":
			fmt.Println("Received SIGTERM")
			exitStatus = 13
		case "SIGKILL":
			fmt.Println("Received SIGKILL")
			exitStatus = 27
		default:
			fmt.Printf("Received unhandled signal: %s\n", s)
			exitStatus = 17
		}
	}()

	<-done
	os.Exit(exitStatus)
}
