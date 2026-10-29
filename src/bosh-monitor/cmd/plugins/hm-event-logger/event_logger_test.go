package main

import (
	"encoding/json"
	"io"
	"strings"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/plugintestutil"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

const cmdTimeout = 3 * time.Second

func startPlugin(t *testing.T) (io.WriteCloser, <-chan *pluginproto.Command) {
	t.Helper()
	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runEventLogger) }()
	plugintestutil.SendInit(t, stdinW, nil)
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout) // startup msg
	return stdinW, cmds
}

// Ruby: alert event → creates event log via director API POST /events
func TestEventLoggerAlertCreatesEvent(t *testing.T) {
	t.Parallel()
	stdinW, cmds := startPlugin(t)
	defer stdinW.Close()

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:       "alert",
		ID:         "alert-1",
		Title:      "disk full",
		Severity:   2,
		Source:     "my-source",
		Deployment: "mycloud",
		Job:        "web",
		InstanceID: "inst-1",
		CreatedAt:  1700000000,
	})

	// Expect a log command and an http_request command
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)
	httpCmd := plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandHTTPRequest, cmdTimeout)

	if httpCmd.Method != "POST" {
		t.Errorf("expected POST method, got %q", httpCmd.Method)
	}
	if httpCmd.URL != "/events" {
		t.Errorf("expected URL /events, got %q", httpCmd.URL)
	}

	var body map[string]interface{}
	if err := json.Unmarshal([]byte(httpCmd.Body), &body); err != nil {
		t.Fatalf("expected valid JSON body: %v", err)
	}
	if body["action"] != "create" {
		t.Errorf("expected action=create, got %v", body["action"])
	}
	if body["object_type"] != "alert" {
		t.Errorf("expected object_type=alert, got %v", body["object_type"])
	}
	if body["object_name"] != "alert-1" {
		t.Errorf("expected object_name=alert-1, got %v", body["object_name"])
	}
	if body["deployment"] != "mycloud" {
		t.Errorf("expected deployment=mycloud, got %v", body["deployment"])
	}
	// instance field should be "job/instance_id"
	if body["instance"] != "web/inst-1" {
		t.Errorf("expected instance=web/inst-1, got %v", body["instance"])
	}
}

// Non-alert events (heartbeats) are ignored.
func TestEventLoggerHeartbeatIgnored(t *testing.T) {
	t.Parallel()
	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runEventLogger) }()
	plugintestutil.SendInit(t, stdinW, nil)
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout) // startup

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{Kind: "heartbeat", ID: "hb-1"})

	// Expect no http_request within 500 ms
	timer := time.NewTimer(500 * time.Millisecond)
	defer timer.Stop()
	for {
		select {
		case cmd := <-cmds:
			if cmd.Cmd == pluginproto.CommandHTTPRequest {
				t.Errorf("heartbeat should not trigger an http_request, got: %+v", cmd)
			}
		case <-timer.C:
			return // success — no http_request arrived
		}
	}
}

// context message contains the title and severity.
func TestEventLoggerContextMessage(t *testing.T) {
	t.Parallel()
	stdinW, cmds := startPlugin(t)
	defer stdinW.Close()

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:      "alert",
		ID:        "a1",
		Title:     "my-title",
		Severity:  3,
		Source:    "src",
		CreatedAt: 1700000000,
	})

	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)
	httpCmd := plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandHTTPRequest, cmdTimeout)

	var body map[string]interface{}
	_ = json.Unmarshal([]byte(httpCmd.Body), &body)
	ctx, _ := body["context"].(map[string]interface{})
	msg, _ := ctx["message"].(string)
	if !strings.Contains(msg, "my-title") {
		t.Errorf("context message should contain title, got %q", msg)
	}
	if !strings.Contains(msg, "3") {
		t.Errorf("context message should contain severity, got %q", msg)
	}
}
