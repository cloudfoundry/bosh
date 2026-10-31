package pluginlib_test

import (
	"bytes"
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

// TestShutdownWithOrphanGoroutineDoesNotPanic is the regression test for the
// "send on closed channel" panic: several plugins (resurrector, email, datadog,
// ...) spawn goroutines that send on cmds after the main loop has returned.
// The framework must never close cmdsCh out from under them.
func TestShutdownWithOrphanGoroutineDoesNotPanic(t *testing.T) {
	var stdin bytes.Buffer
	if err := pluginproto.WriteEnvelope(&stdin, pluginproto.NewInitEnvelope(nil)); err != nil {
		t.Fatal(err)
	}
	if err := pluginproto.WriteEnvelope(&stdin, pluginproto.NewShutdownEnvelope()); err != nil {
		t.Fatal(err)
	}

	done := make(chan error, 1)
	go func() {
		done <- pluginlib.RunWithIO(&stdin, &bytes.Buffer{}, func(ctx context.Context, _ json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
			// Orphan goroutine that keeps trying to emit after shutdown.
			go func() {
				for {
					select {
					case <-ctx.Done():
						// Even after cancellation, a late bare send must not panic.
						pluginlib.SendCommand(ctx, cmds, pluginlib.LogCommand("info", "late"))
						return
					case <-time.After(time.Millisecond):
						pluginlib.SendCommand(ctx, cmds, pluginlib.LogCommand("info", "tick"))
					}
				}
			}()
			for range events {
			}
			return nil
		})
	}()

	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("RunWithIO returned error: %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("RunWithIO did not return after shutdown")
	}
}
