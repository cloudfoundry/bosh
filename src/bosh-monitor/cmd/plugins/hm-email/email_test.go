package main

import (
	"context"
	"encoding/json"
	"io"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/plugintestutil"
)

const pluginTimeout = 3 * time.Second

func TestEmailLogsQueueProcessing(t *testing.T) {
	t.Parallel()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	cmds := make(chan *pluginlib.Command, 10)
	errCh := make(chan error, 1)
	go func() {
		errCh <- runEmail(ctx, json.RawMessage(`{"recipients":["user@example.com"],"smtp":{"host":"localhost"},"interval":0.01}`), make(chan *pluginlib.EventEnvelope), cmds)
	}()
	t.Cleanup(func() {
		cancel()
		select {
		case err := <-errCh:
			if err != nil {
				t.Errorf("email plugin failed: %v", err)
			}
		case <-time.After(pluginTimeout):
			t.Error("email plugin did not stop")
		}
	})

	deadline := time.NewTimer(pluginTimeout)
	defer deadline.Stop()
	for {
		select {
		case cmd := <-cmds:
			if cmd.Cmd == "log" && cmd.Message == "Processing queues..." {
				if cmd.Level != "info" {
					t.Errorf("expected info log, got %q", cmd.Level)
				}
				return
			}
		case <-deadline.C:
			t.Fatal("expected queue-processing log")
		}
	}
}

// Ruby: "validates options" — missing recipients → false
func TestEmailMissingRecipients(t *testing.T) {
	t.Parallel()
	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	_ = plugintestutil.CmdSink(stdoutR)
	errCh := make(chan error, 1)
	go func() { errCh <- pluginlib.RunWithIO(stdinR, stdoutW, runEmail) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{
		"smtp": map[string]interface{}{"host": "localhost"},
	})
	stdinW.Close()
	select {
	case err := <-errCh:
		if err == nil {
			t.Error("expected startup error for missing recipients, got nil")
		}
	case <-time.After(pluginTimeout):
		t.Fatal("timed out waiting for plugin error")
	}
}

// Ruby: "validates options" — missing smtp options → false
func TestEmailMissingSMTP(t *testing.T) {
	t.Parallel()
	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	_ = plugintestutil.CmdSink(stdoutR)
	errCh := make(chan error, 1)
	go func() { errCh <- pluginlib.RunWithIO(stdinR, stdoutW, runEmail) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{
		"recipients": []interface{}{"user@example.com"},
	})
	stdinW.Close()
	select {
	case err := <-errCh:
		if err == nil {
			t.Error("expected startup error for missing smtp options, got nil")
		}
	case <-time.After(pluginTimeout):
		t.Fatal("timed out waiting for plugin error")
	}
}

// Ruby: "does not start if event loop is not running" — in Go this means options
// are validated before the plugin enters its event loop. Valid options should
// start the plugin and stop cleanly on stdin close.
func TestEmailValidOptionsStart(t *testing.T) {
	t.Parallel()
	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	errCh := make(chan error, 1)
	go func() { errCh <- pluginlib.RunWithIO(stdinR, stdoutW, runEmail) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{
		"recipients": []interface{}{"user@example.com"},
		"smtp":       map[string]interface{}{"host": "localhost", "port": float64(587)},
		"interval":   float64(3600), // large interval so no actual send attempt
	})
	plugintestutil.SkipReady(t, cmds)
	// Close stdin to shut down cleanly
	stdinW.Close()
	select {
	case err := <-errCh:
		if err != nil {
			t.Errorf("expected clean shutdown, got error: %v", err)
		}
	case <-time.After(pluginTimeout):
		t.Fatal("plugin did not stop after stdin close")
	}
}
