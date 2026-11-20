package main

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/plugintestutil"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

const cmdTimeout = 3 * time.Second

// Ruby: "validates options" — missing service_key → false
func TestPagerdutyMissingServiceKey(t *testing.T) {
	t.Parallel()
	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	_ = plugintestutil.CmdSink(stdoutR)
	errCh := make(chan error, 1)
	go func() { errCh <- pluginlib.RunWithIO(stdinR, stdoutW, runPagerduty) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{})
	stdinW.Close()
	select {
	case err := <-errCh:
		if err == nil {
			t.Error("expected startup error for missing service_key, got nil")
		}
	case <-time.After(3 * time.Second):
		t.Fatal("timed out waiting for plugin error")
	}
}

// Ruby: "sends events to Pagerduty" — alert → POST with service_key + incident details
// Not run in parallel: modifies the package-level apiURI variable.
func TestPagerdutyAlertPost(t *testing.T) {

	received := make(chan []byte, 1)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		received <- body
		w.WriteHeader(200)
	}))
	defer srv.Close()

	// Override the hardcoded URL for this test
	origURI := apiURI
	apiURI = srv.URL
	defer func() { apiURI = origURI }()

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runPagerduty) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{"service_key": "zbzb"})
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:       "alert",
		ID:         "alert-1",
		Severity:   2,
		Title:      "disk full",
		Summary:    "disk is 95% full",
		Source:     "my-source",
		Deployment: "mycloud",
		CreatedAt:  1700000000,
	})

	select {
	case body := <-received:
		var payload map[string]interface{}
		if err := json.Unmarshal(body, &payload); err != nil {
			t.Fatalf("PagerDuty POST body is not JSON: %v — got %q", err, body)
		}
		if payload["service_key"] != "zbzb" {
			t.Errorf("expected service_key=zbzb, got %v", payload["service_key"])
		}
		if payload["event_type"] != "trigger" {
			t.Errorf("expected event_type=trigger, got %v", payload["event_type"])
		}
		if payload["incident_key"] != "alert-1" {
			t.Errorf("expected incident_key=alert-1, got %v", payload["incident_key"])
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for PagerDuty POST")
	}
	stdinW.Close()
}

// Ruby: "sends events to Pagerduty" — heartbeat → POST with heartbeat description
// Not run in parallel: modifies the package-level apiURI variable.
func TestPagerdutyHeartbeatPost(t *testing.T) {

	received := make(chan []byte, 1)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		received <- body
		w.WriteHeader(200)
	}))
	defer srv.Close()

	origURI := apiURI
	apiURI = srv.URL
	defer func() { apiURI = origURI }()

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runPagerduty) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{"service_key": "zbzb"})
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:       "heartbeat",
		ID:         "hb-1",
		Deployment: "mycloud",
		Job:        "web",
		InstanceID: "inst-1",
		AgentID:    "agent-1",
	})

	select {
	case body := <-received:
		var payload map[string]interface{}
		if err := json.Unmarshal(body, &payload); err != nil {
			t.Fatalf("PagerDuty heartbeat POST body is not JSON: %v", err)
		}
		if payload["service_key"] != "zbzb" {
			t.Errorf("expected service_key=zbzb, got %v", payload["service_key"])
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for PagerDuty heartbeat POST")
	}
	stdinW.Close()
}
