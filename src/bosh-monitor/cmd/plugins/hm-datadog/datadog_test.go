package main

import (
	"encoding/json"
	"io"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/plugintestutil"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

const cmdTimeout = 3 * time.Second

// Ruby: "validating the options" — missing api_key or application_key → invalid
func TestDatadogMissingOptions(t *testing.T) {
	for name, opts := range map[string]map[string]interface{}{
		"missing api_key":         {"application_key": "app_key"},
		"missing application_key": {"api_key": "api_key"},
		"missing both":            {},
	} {
		opts := opts
		stdinR, stdinW := io.Pipe()
		stdoutR, stdoutW := io.Pipe()
		_ = plugintestutil.CmdSink(stdoutR)
		errCh := make(chan error, 1)
		go func() { errCh <- pluginlib.RunWithIO(stdinR, stdoutW, runDatadog) }()
		plugintestutil.SendInit(t, stdinW, opts)
		stdinW.Close()
		select {
		case err := <-errCh:
			if err == nil {
				t.Errorf("%s: expected startup error, got nil", name)
			}
		case <-time.After(3 * time.Second):
			t.Fatalf("%s: timed out", name)
		}
	}
}

// Ruby: "processing metrics" — heartbeat → POST to /api/v1/series with bosh.healthmonitor.* metrics
// Not run in parallel: modifies package-level URL template variable.
func TestDatadogHeartbeatSendsSeries(t *testing.T) {

	received := make(chan []byte, 1)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := ioutil.ReadAll(r.Body)
		received <- body
		w.WriteHeader(200)
	}))
	defer srv.Close()

	origSeries := datadogSeriesURLTemplate
	datadogSeriesURLTemplate = srv.URL + "?api_key=%s"
	defer func() { datadogSeriesURLTemplate = origSeries }()

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runDatadog) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{
		"api_key":         "test-api-key",
		"application_key": "test-app-key",
	})
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:       "heartbeat",
		ID:         "hb-1",
		Deployment: "mycloud",
		Job:        "web",
		InstanceID: "inst-1",
		AgentID:    "a1",
		Metrics: []pluginproto.MetricData{
			{Name: "system.load.1m", Value: "0.5", Timestamp: 1700000001},
		},
	})

	select {
	case body := <-received:
		var payload map[string]interface{}
		if err := json.Unmarshal(body, &payload); err != nil {
			t.Fatalf("Datadog heartbeat body is not JSON: %v", err)
		}
		series, _ := payload["series"].([]interface{})
		if len(series) == 0 {
			t.Fatal("expected at least one series entry")
		}
		m := series[0].(map[string]interface{})
		metricName, _ := m["metric"].(string)
		if !strings.HasPrefix(metricName, "bosh.healthmonitor.") {
			t.Errorf("expected metric name starting with 'bosh.healthmonitor.', got %q", metricName)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for Datadog series POST")
	}
	stdinW.Close()
}

// Ruby: alert → POST to /api/v1/events with title, priority, alert_type
// Not run in parallel: modifies package-level URL template variable.
func TestDatadogAlertSendsEvent(t *testing.T) {

	received := make(chan []byte, 1)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := ioutil.ReadAll(r.Body)
		received <- body
		w.WriteHeader(200)
	}))
	defer srv.Close()

	origEvents := datadogEventsURLTemplate
	datadogEventsURLTemplate = srv.URL + "?api_key=%s"
	defer func() { datadogEventsURLTemplate = origEvents }()

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runDatadog) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{
		"api_key":         "test-api-key",
		"application_key": "test-app-key",
	})
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:       "alert",
		ID:         "a1",
		Severity:   2, // normal priority + error alert_type
		Title:      "disk full",
		Summary:    "disk is full",
		Source:     "hm",
		Deployment: "mycloud",
		CreatedAt:  1700000000,
	})

	select {
	case body := <-received:
		var payload map[string]interface{}
		if err := json.Unmarshal(body, &payload); err != nil {
			t.Fatalf("Datadog event body is not JSON: %v", err)
		}
		if payload["title"] != "disk full" {
			t.Errorf("expected title='disk full', got %v", payload["title"])
		}
		if payload["priority"] != "normal" {
			t.Errorf("expected priority=normal for severity 2, got %v", payload["priority"])
		}
		if payload["alert_type"] != "error" {
			t.Errorf("expected alert_type=error, got %v", payload["alert_type"])
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for Datadog events POST")
	}
	stdinW.Close()
}

// PagerDuty service name appended to alert text when configured.
// Not run in parallel: modifies package-level URL template variable.
func TestDatadogPagerdutyServiceName(t *testing.T) {

	received := make(chan []byte, 1)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := ioutil.ReadAll(r.Body)
		received <- body
		w.WriteHeader(200)
	}))
	defer srv.Close()

	origEvents := datadogEventsURLTemplate
	datadogEventsURLTemplate = srv.URL + "?api_key=%s"
	defer func() { datadogEventsURLTemplate = origEvents }()

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runDatadog) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{
		"api_key":                "test-api-key",
		"application_key":        "test-app-key",
		"pagerduty_service_name": "my-service",
	})
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:      "alert",
		ID:        "a2",
		Severity:  1, // triggers @service_name append
		Title:     "host down",
		Summary:   "host is unreachable",
		CreatedAt: 1700000000,
	})

	select {
	case body := <-received:
		var payload map[string]interface{}
		_ = json.Unmarshal(body, &payload)
		text, _ := payload["text"].(string)
		if !strings.Contains(text, "@my-service") {
			t.Errorf("expected text to contain '@my-service', got %q", text)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for Datadog events POST with PD service name")
	}
	stdinW.Close()
}
