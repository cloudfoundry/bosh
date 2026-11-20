package pluginhost

import (
	"io"
	"log/slog"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

// TestSendEnvelopeNeverBlocksWhenBufferFull verifies the core back-pressure
// guarantee: dispatch runs while the instance-manager lock is held, so sending
// to a plugin that has stopped reading its stdin must never block — it must
// drop and return promptly. A regression here would let one wedged plugin stall
// the entire monitor.
func TestSendEnvelopeNeverBlocksWhenBufferFull(t *testing.T) {
	p := &PluginProcess{
		name:    "stuck",
		logger:  slog.New(slog.NewTextHandler(io.Discard, nil)),
		running: true,
		sendCh:  make(chan *pluginproto.Envelope, 1),
	}

	// Fill the buffer; nothing is consuming it (simulating a wedged plugin).
	p.sendCh <- pluginproto.NewShutdownEnvelope()

	done := make(chan struct{})
	go func() {
		// These would block forever with a synchronous writer.
		for i := 0; i < 100; i++ {
			p.SendEnvelope(pluginproto.NewEventEnvelope(&pluginproto.EventData{Kind: "alert"}))
		}
		close(done)
	}()

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("SendEnvelope blocked when the plugin send buffer was full")
	}
}

// TestSendEnvelopeNoopWhenNotRunning verifies sending to a stopped process is a
// safe no-op rather than a panic or block.
func TestSendEnvelopeNoopWhenNotRunning(t *testing.T) {
	p := &PluginProcess{
		name:    "stopped",
		logger:  slog.New(slog.NewTextHandler(io.Discard, nil)),
		running: false,
	}
	p.SendEnvelope(pluginproto.NewShutdownEnvelope()) // must not panic
}

func TestBackoffDelayIsCapped(t *testing.T) {
	if got := backoffDelay(1); got != restartBackoffBase {
		t.Errorf("attempt 1: want %v, got %v", restartBackoffBase, got)
	}
	if got := backoffDelay(2); got != 2*restartBackoffBase {
		t.Errorf("attempt 2: want %v, got %v", 2*restartBackoffBase, got)
	}
	if got := backoffDelay(100); got != restartBackoffMax {
		t.Errorf("attempt 100: want cap %v, got %v", restartBackoffMax, got)
	}
}
