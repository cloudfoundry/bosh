package main

import (
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/plugintestutil"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

const cmdTimeout = 3 * time.Second

// Ruby: "validates options" — missing host/port/protocol → error
func TestConsulMissingOptions(t *testing.T) {
	for name, opts := range map[string]map[string]interface{}{
		"missing host":     {"port": float64(8500), "protocol": "http"},
		"missing port":     {"host": "localhost", "protocol": "http"},
		"missing protocol": {"host": "localhost", "port": float64(8500)},
	} {
		opts := opts
		stdinR, stdinW := io.Pipe()
		stdoutR, stdoutW := io.Pipe()
		_ = plugintestutil.CmdSink(stdoutR)
		errCh := make(chan error, 1)
		go func() { errCh <- pluginlib.RunWithIO(stdinR, stdoutW, runConsul) }()
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

// Ruby: alert event with events=true → PUT to /v1/event/fire/<label>
func TestConsulForwardsAlertEvent(t *testing.T) {
	t.Parallel()

	received := make(chan string, 10)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		received <- r.URL.Path
		w.WriteHeader(200)
	}))
	defer srv.Close()

	u, _ := url.Parse(srv.URL)
	host := u.Hostname()
	port, _ := strconv.Atoi(u.Port())

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runConsul) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{
		"host":     host,
		"port":     float64(port),
		"protocol": "http",
		"events":   true,
	})
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout) // startup

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:    "alert",
		ID:      "a1",
		Title:   "something failed",
		Summary: "disk full",
	})

	select {
	case path := <-received:
		if !strings.HasPrefix(path, "/v1/event/fire/") {
			t.Errorf("expected PUT to /v1/event/fire/..., got %q", path)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("timed out waiting for Consul HTTP request")
	}

	stdinW.Close()
}

// Heartbeat with TTL config → check register then check update.
func TestConsulTTLHeartbeat(t *testing.T) {
	t.Parallel()

	received := make(chan string, 10)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		received <- r.URL.Path
		w.WriteHeader(200)
	}))
	defer srv.Close()

	u, _ := url.Parse(srv.URL)
	host := u.Hostname()
	port, _ := strconv.Atoi(u.Port())

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runConsul) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{
		"host":     host,
		"port":     float64(port),
		"protocol": "http",
		"ttl":      "30s",
	})
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:       "heartbeat",
		ID:         "hb-1",
		Deployment: "dep",
		Job:        "web",
		InstanceID: "i1",
		AgentID:    "a1",
		JobState:   "running",
	})

	// First request should be a check registration
	select {
	case path := <-received:
		if !strings.HasPrefix(path, "/v1/agent/check/") {
			t.Errorf("expected /v1/agent/check/... path, got %q", path)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("timed out waiting for Consul TTL request")
	}
	stdinW.Close()
}
