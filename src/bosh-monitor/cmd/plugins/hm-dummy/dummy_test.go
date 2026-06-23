package main

import (
	"io"
	"strings"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/plugintestutil"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

const cmdTimeout = 3 * time.Second

// Ruby: "retains a list of previously made alerts" — processes events and logs them
func TestDummyProcessesEvents(t *testing.T) {
	t.Parallel()

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runDummy) }()

	plugintestutil.SendInit(t, stdinW, nil)
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout) // startup msg

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{Kind: "heartbeat", ID: "hb-1"})
	cmd1 := plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)
	if !strings.Contains(cmd1.Message, "total: 1") {
		t.Errorf("expected 'total: 1', got %q", cmd1.Message)
	}

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{Kind: "alert", ID: "alert-1"})
	cmd2 := plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)
	if !strings.Contains(cmd2.Message, "total: 2") {
		t.Errorf("expected 'total: 2', got %q", cmd2.Message)
	}

	stdinW.Close()
}

// Graceful stop via stdin close.
func TestDummyStopsOnStdinClose(t *testing.T) {
	t.Parallel()
	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	_ = plugintestutil.CmdSink(stdoutR)
	errCh := make(chan error, 1)
	go func() { errCh <- pluginlib.RunWithIO(stdinR, stdoutW, runDummy) }()
	plugintestutil.SendInit(t, stdinW, nil)
	stdinW.Close()

	select {
	case err := <-errCh:
		if err != nil {
			t.Errorf("expected nil error on clean shutdown, got %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("plugin did not stop after stdin was closed")
	}
}
