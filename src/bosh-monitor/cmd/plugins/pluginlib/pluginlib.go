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

	errCh := make(chan error, 1)
	go func() {
		errCh <- fn(ctx, optionsJSON, eventsCh, cmdsCh)
	}()

	readyCmd := pluginproto.NewReadyCommand()
	if err := pluginproto.WriteCommand(stdout, readyCmd); err != nil {
		return fmt.Errorf("failed to write ready command: %w", err)
	}

	cmdsDone := make(chan struct{})
	go func() {
		for cmd := range cmdsCh {
			if err := pluginproto.WriteCommand(stdout, cmd); err != nil {
				fmt.Fprintf(os.Stderr, "failed to write command: %v\n", err)
			}
		}
		close(cmdsDone)
	}()

	drainAndWait := func() error {
		fnErr := <-errCh
		close(cmdsCh)
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
		case pluginproto.EnvelopeTypeEvent:
			eventsCh <- &env
		case pluginproto.EnvelopeTypeShutdown:
			cancel()
			close(eventsCh)
			return drainAndWait()
		case pluginproto.EnvelopeTypeHTTPResponse:
			eventsCh <- &env
		}
	}

	cancel()
	close(eventsCh)
	return drainAndWait()
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
