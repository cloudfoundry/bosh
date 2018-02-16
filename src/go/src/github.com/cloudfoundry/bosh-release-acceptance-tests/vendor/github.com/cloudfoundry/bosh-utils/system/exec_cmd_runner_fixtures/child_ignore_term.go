package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	fmt.Printf("child_pid=%d\n", os.Getpid())

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGKILL)

	go func() {
		for {
			switch <-sigCh {
			case syscall.SIGTERM:
				fmt.Printf("Child received SIGTERM\n")
			case syscall.SIGKILL:
				fmt.Printf("Child received SIGKILL\n")
			}
		}
	}()

	select {}
}
