// Package plugintestutil provides helpers shared by plugin unit tests.
// It is a regular (non-test) package so it can be imported from _test.go
// files in other packages.
package plugintestutil

import (
	"bufio"
	"encoding/json"
	"io"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

// CmdSink continuously reads JSON commands from r, sending each one to the
// returned channel. The goroutine exits when r is closed. Buffering prevents
// the pipe from blocking when the test does not consume every command.
func CmdSink(r io.Reader) <-chan *pluginproto.Command {
	ch := make(chan *pluginproto.Command, 256)
	go func() {
		scanner := bufio.NewScanner(r)
		for scanner.Scan() {
			var cmd pluginproto.Command
			if err := json.Unmarshal(scanner.Bytes(), &cmd); err == nil {
				ch <- &cmd
			}
		}
		close(ch)
	}()
	return ch
}

// SendEnvelope marshals env as a JSON line and writes it to w.
func SendEnvelope(t *testing.T, w io.Writer, env *pluginproto.Envelope) {
	t.Helper()
	data, err := json.Marshal(env)
	if err != nil {
		t.Fatalf("marshal envelope: %v", err)
	}
	if _, err := w.Write(append(data, '\n')); err != nil {
		t.Logf("write envelope (%s): %v", env.Type, err)
	}
}

// SendInit writes an init envelope with the given options map to w.
func SendInit(t *testing.T, w io.Writer, opts map[string]interface{}) {
	t.Helper()
	SendEnvelope(t, w, &pluginproto.Envelope{Type: pluginproto.EnvelopeTypeInit, Options: opts})
}

// SendEvent writes an event envelope to w.
func SendEvent(t *testing.T, w io.Writer, event *pluginproto.EventData) {
	t.Helper()
	SendEnvelope(t, w, &pluginproto.Envelope{Type: pluginproto.EnvelopeTypeEvent, Event: event})
}

// SendShutdown writes a shutdown envelope to w.
func SendShutdown(t *testing.T, w io.Writer) {
	t.Helper()
	SendEnvelope(t, w, &pluginproto.Envelope{Type: pluginproto.EnvelopeTypeShutdown})
}

// NextCmd returns the next command from ch, or fatally times out.
func NextCmd(t *testing.T, ch <-chan *pluginproto.Command, timeout time.Duration) *pluginproto.Command {
	t.Helper()
	select {
	case cmd, ok := <-ch:
		if !ok {
			t.Fatal("command channel closed unexpectedly")
		}
		return cmd
	case <-time.After(timeout):
		t.Fatalf("timed out after %v waiting for a command (possible deadlock)", timeout)
		return nil
	}
}

// NextCmdOfType drains commands until one of the target type is found, or
// the deadline is reached.
func NextCmdOfType(t *testing.T, ch <-chan *pluginproto.Command, want string, timeout time.Duration) *pluginproto.Command {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			break
		}
		cmd := NextCmd(t, ch, remaining)
		if cmd.Cmd == want {
			return cmd
		}
		t.Logf("skipping unexpected command %q while waiting for %q", cmd.Cmd, want)
	}
	t.Fatalf("did not receive command %q within %v", want, timeout)
	return nil
}

// SkipReady drains commands until the "ready" command is consumed.
func SkipReady(t *testing.T, ch <-chan *pluginproto.Command) {
	t.Helper()
	NextCmdOfType(t, ch, pluginproto.CommandReady, 5*time.Second)
}
