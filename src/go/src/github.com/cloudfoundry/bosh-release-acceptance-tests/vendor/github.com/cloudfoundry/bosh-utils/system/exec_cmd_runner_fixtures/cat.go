package main

import (
	"bytes"
	"errors"
	"flag"
	"fmt"
	"os"
	"time"
)

var (
	stdoutFlag string
	stderrFlag string
)

func init() {
	flag.StringVar(&stdoutFlag, "stdout", "", "value will be written to Stdout")
	flag.StringVar(&stderrFlag, "stderr", "", "value will be written to Stderr")
}

func TimedReader(buf *bytes.Buffer) error {
	errCh := make(chan error, 1)
	go func() {
		_, err := buf.ReadFrom(os.Stdin)
		errCh <- err
	}()
	select {
	case err := <-errCh:
		return err
	case <-time.After(time.Second):
		return errors.New("timeout")
	}
	return errors.New("THIS SHOULD NEVER HAPPEN!")
}

func main() {
	flag.Parse()

	if stdoutFlag == "" && stderrFlag == "" {
		var buf bytes.Buffer
		if err := TimedReader(&buf); err != nil {
			fmt.Fprintf(os.Stderr, "Error: reading stdin: %s\n", err)
			os.Exit(1)
		}
		if _, err := buf.WriteTo(os.Stdout); err != nil {
			fmt.Fprintf(os.Stderr, "Error: writing to stout: %s\n", err)
			os.Exit(1)
		}
		os.Exit(0)
	}

	if stdoutFlag != "" {
		fmt.Fprintln(os.Stdout, stdoutFlag)
	}
	if stderrFlag != "" {
		fmt.Fprintln(os.Stderr, stderrFlag)
	}
	os.Exit(0)
}
