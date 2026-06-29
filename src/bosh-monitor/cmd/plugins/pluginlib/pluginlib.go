package pluginlib

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

type EventEnvelope = pluginproto.Envelope
type Command = pluginproto.Command
type EventData = pluginproto.EventData

type PluginFunc func(ctx context.Context, options json.RawMessage, events <-chan *EventEnvelope, cmds chan<- *Command) error

// Run starts the plugin lifecycle: reads envelopes from STDIN, dispatches events, and writes commands to STDOUT.
func Run(fn PluginFunc) {
	if err := run(os.Stdin, os.Stdout, fn); err != nil {
		fmt.Fprintf(os.Stderr, "plugin error: %v\n", err)
		os.Exit(1)
	}
}

// RunWithIO is a testable version of Run that accepts explicit readers/writers.
func RunWithIO(stdin io.Reader, stdout io.Writer, fn PluginFunc) error {
	return run(stdin, stdout, fn)
}

func run(stdin io.Reader, stdout io.Writer, fn PluginFunc) error {
	scanner := bufio.NewScanner(stdin)
	scanner.Buffer(make([]byte, 0, 1024*1024), 1024*1024)

	env, err := pluginproto.ReadEnvelope(scanner)
	if err != nil {
		return fmt.Errorf("failed to read init envelope: %w", err)
	}
	if env.Type != pluginproto.EnvelopeTypeInit {
		return fmt.Errorf("expected init envelope, got %s", env.Type)
	}

	optionsJSON, err := json.Marshal(env.Options)
	if err != nil {
		return fmt.Errorf("failed to marshal options: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	eventsCh := make(chan *EventEnvelope, 100)
	cmdsCh := make(chan *Command, 100)

	// Write the initial ready command synchronously, before the writer goroutine
	// starts, so there is never more than one writer touching stdout at a time.
	if err := pluginproto.WriteCommand(stdout, pluginproto.NewReadyCommand()); err != nil {
		return fmt.Errorf("failed to write ready command: %w", err)
	}

	// The writer is stopped via stopWriter, NOT by closing cmdsCh. Closing
	// cmdsCh would race with — and panic — any goroutine the plugin spawned that
	// is still sending on cmds during shutdown (the resurrector, email, datadog,
	// etc. all do this). stopWriter is closed only after fn has returned, so by
	// then every command fn sent directly is already buffered; the writer drains
	// the buffer before exiting, preserving the guarantee that all of fn's
	// commands are flushed. Sends from orphan goroutines after that are dropped
	// (best effort) rather than causing a panic.
	stopWriter := make(chan struct{})
	cmdsDone := make(chan struct{})
	go func() {
		defer close(cmdsDone)
		for {
			select {
			case cmd := <-cmdsCh:
				if err := pluginproto.WriteCommand(stdout, cmd); err != nil {
					fmt.Fprintf(os.Stderr, "failed to write command: %v\n", err)
				}
			case <-stopWriter:
				for {
					select {
					case cmd := <-cmdsCh:
						_ = pluginproto.WriteCommand(stdout, cmd)
					default:
						return
					}
				}
			}
		}
	}()

	errCh := make(chan error, 1)
	go func() {
		errCh <- fn(ctx, optionsJSON, eventsCh, cmdsCh)
	}()

	drainAndWait := func() error {
		fnErr := <-errCh  // fn has fully returned; all its direct sends are buffered
		cancel()          // stop any orphan plugin goroutines / ctx-aware work
		close(stopWriter) // tell the writer to flush the buffer and exit
		<-cmdsDone
		return fnErr
	}

	for scanner.Scan() {
		var env pluginproto.Envelope
		if err := json.Unmarshal(scanner.Bytes(), &env); err != nil {
			fmt.Fprintf(os.Stderr, "failed to parse envelope: %v\n", err)
			continue
		}

		switch env.Type {
		case pluginproto.EnvelopeTypeEvent, pluginproto.EnvelopeTypeHTTPResponse:
			select {
			case eventsCh <- &env:
			case <-ctx.Done():
			}
		case pluginproto.EnvelopeTypeShutdown:
			cancel()
			close(eventsCh)
			return drainAndWait()
		}
	}

	cancel()
	close(eventsCh)
	return drainAndWait()
}

// SendCommand sends a command without blocking past plugin shutdown. Plugin
// goroutines that may outlive the main event loop (e.g. ones waiting on an HTTP
// response) should use this instead of a bare `cmds <- cmd` so that a shutdown
// in flight cannot leak the goroutine on a full channel.
func SendCommand(ctx context.Context, cmds chan<- *Command, cmd *Command) {
	select {
	case cmds <- cmd:
	case <-ctx.Done():
	}
}

// LogCommand creates a log command.
func LogCommand(level, message string) *Command {
	return pluginproto.NewLogCommand(level, message)
}

// EmitAlertCommand creates an emit_alert command.
func EmitAlertCommand(alert map[string]interface{}) *Command {
	return pluginproto.NewEmitAlertCommand(alert)
}

// HTTPRequestCommand creates an http_request command.
func HTTPRequestCommand(id, method, url string, headers map[string]string, body string) *Command {
	return pluginproto.NewHTTPRequestCommand(id, method, url, headers, body, true)
}

// HTTPGetCommand creates an http_get command.
func HTTPGetCommand(id, url string) *Command {
	return pluginproto.NewHTTPGetCommand(id, url, true)
}
