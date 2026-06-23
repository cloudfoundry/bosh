package main

import (
	"encoding/json"
	"io"
	"strings"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/plugintestutil"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

const cmdTimeout = 3 * time.Second

func runPlugin(t *testing.T, opts map[string]interface{}) (io.WriteCloser, <-chan *pluginproto.Command, <-chan error) {
	t.Helper()
	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	errCh := make(chan error, 1)
	go func() { errCh <- pluginlib.RunWithIO(stdinR, stdoutW, runLogger) }()
	plugintestutil.SendInit(t, stdinW, opts)
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout) // skip startup msg
	return stdinW, cmds, errCh
}

// Ruby: "without options" → "writes events to log" as "[HEARTBEAT] ..." / "[ALERT] ..."
func TestLoggerTextFormatHeartbeat(t *testing.T) {
	t.Parallel()
	stdinW, cmds, _ := runPlugin(t, nil)
	defer stdinW.Close()

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:       "heartbeat",
		ID:         "hb-1",
		Job:        "web",
		InstanceID: "inst-1",
		AgentID:    "agent-1",
		Timestamp:  1700000000,
	})

	cmd := plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)
	if !strings.HasPrefix(cmd.Message, "[HEARTBEAT]") {
		t.Errorf("expected log message to start with [HEARTBEAT], got %q", cmd.Message)
	}
}

func TestLoggerTextFormatAlert(t *testing.T) {
	t.Parallel()
	stdinW, cmds, _ := runPlugin(t, nil)
	defer stdinW.Close()

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:      "alert",
		ID:        "alert-1",
		Severity:  2,
		Summary:   "disk full",
		CreatedAt: 1700000000,
	})

	cmd := plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)
	if !strings.HasPrefix(cmd.Message, "[ALERT]") {
		t.Errorf("expected log message to start with [ALERT], got %q", cmd.Message)
	}
	if !strings.Contains(cmd.Message, "disk full") {
		t.Errorf("expected log message to contain summary, got %q", cmd.Message)
	}
}

// Ruby: "with json output option" → "writes events to log as json"
func TestLoggerJSONFormat(t *testing.T) {
	t.Parallel()
	stdinW, cmds, _ := runPlugin(t, map[string]interface{}{"format": "json"})
	defer stdinW.Close()

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:      "alert",
		ID:        "alert-json-1",
		Severity:  3,
		Summary:   "test summary",
		CreatedAt: 1700000001,
	})

	cmd := plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)
	var parsed map[string]interface{}
	if err := json.Unmarshal([]byte(cmd.Message), &parsed); err != nil {
		t.Errorf("JSON format output is not valid JSON: %v — got %q", err, cmd.Message)
	}
	if parsed["kind"] != "alert" {
		t.Errorf("expected kind=alert in JSON output, got %v", parsed["kind"])
	}
}

// Logger plugin emits a startup log and accepts any options.
func TestLoggerStartupLog(t *testing.T) {
	t.Parallel()
	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runLogger) }()
	plugintestutil.SendInit(t, stdinW, nil)
	plugintestutil.SkipReady(t, cmds)
	// First log after ready is the startup message
	cmd := plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)
	if !strings.Contains(cmd.Message, "Logging delivery agent is running") {
		t.Errorf("unexpected startup log: %q", cmd.Message)
	}
	stdinW.Close()
}
