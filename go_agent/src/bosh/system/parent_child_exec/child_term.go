package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	fmt.Printf("child_pid=%d\n", os.Getpid())

	sigTermCh := make(chan os.Signal, 1)
	signal.Notify(sigTermCh, syscall.SIGTERM)

	go func() {
		<-sigTermCh
		fmt.Printf("Child received SIGTERM")
		os.Exit(14)
	}()

	select {}
}
