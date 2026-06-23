package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/plugintestutil"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

const cmdTimeout = 3 * time.Second

func startTCPListener(t *testing.T) (string, <-chan []byte) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	t.Cleanup(func() { ln.Close() })
	ch := make(chan []byte, 10)
	go func() {
		for {
			conn, err := ln.Accept()
			if err != nil {
				return
			}
			go func(c net.Conn) {
				defer c.Close()
				data, _ := io.ReadAll(c)
				ch <- data
			}(conn)
		}
	}()
	return ln.Addr().String(), ch
}

// Ruby: "validates options" — missing host or port → error
func TestRiemannMissingOptions(t *testing.T) {
	for _, opts := range []map[string]interface{}{
		{"host": "127.0.0.1"}, // missing port
		{"port": float64(5555)}, // missing host
	} {
		stdinR, stdinW := io.Pipe()
		stdoutR, stdoutW := io.Pipe()
		_ = plugintestutil.CmdSink(stdoutR)
		errCh := make(chan error, 1)
		go func() { errCh <- pluginlib.RunWithIO(stdinR, stdoutW, runRiemann) }()
		plugintestutil.SendInit(t, stdinW, opts)
		stdinW.Close()
		select {
		case err := <-errCh:
			if err == nil {
				t.Errorf("expected error for opts %v, got nil", opts)
			}
		case <-time.After(3 * time.Second):
			t.Fatalf("timed out for opts %v", opts)
		}
	}
}

// Ruby: "sends events to Riemann" — alert → JSON payload with service=bosh.hm, state=critical
func TestRiemannSendsAlert(t *testing.T) {
	t.Parallel()

	addr, received := startTCPListener(t)
	host, portStr, _ := net.SplitHostPort(addr)
	var port int
	fmt.Sscan(portStr, &port)

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runRiemann) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{"host": host, "port": float64(port)})
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:       "alert",
		ID:         "alert-1",
		Severity:   2, // critical
		Title:      "disk full",
		Summary:    "disk is 95% full",
		Source:     "my-source",
		Deployment: "mycloud",
		CreatedAt:  1700000000,
	})

	select {
	case data := <-received:
		var payload map[string]interface{}
		if err := json.Unmarshal(data, &payload); err != nil {
			t.Fatalf("Riemann data is not JSON: %v — got %q", err, data)
		}
		if payload["service"] != "bosh.hm" {
			t.Errorf("expected service=bosh.hm, got %v", payload["service"])
		}
		if payload["state"] != "critical" {
			t.Errorf("expected state=critical for severity 2, got %v", payload["state"])
		}
		if payload["kind"] != "alert" {
			t.Errorf("expected kind=alert, got %v", payload["kind"])
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for Riemann TCP data")
	}
	stdinW.Close()
}

// Ruby: "sends events to Riemann" — heartbeat → service=bosh.hm, name=metric_name
func TestRiemannSendsHeartbeatMetric(t *testing.T) {
	t.Parallel()

	addr, received := startTCPListener(t)
	host, portStr, _ := net.SplitHostPort(addr)
	var port int
	fmt.Sscan(portStr, &port)

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runRiemann) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{"host": host, "port": float64(port)})
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:       "heartbeat",
		ID:         "hb-1",
		Deployment: "mycloud",
		Job:        "web",
		InstanceID: "inst-1",
		AgentID:    "a1",
		Timestamp:  1700000000,
		Metrics: []pluginproto.MetricData{
			{Name: "system.load.1m", Value: "0.2"},
		},
	})

	select {
	case data := <-received:
		var payload map[string]interface{}
		if err := json.Unmarshal(data, &payload); err != nil {
			t.Fatalf("Riemann data is not JSON: %v — got %q", err, data)
		}
		if payload["service"] != "bosh.hm" {
			t.Errorf("expected service=bosh.hm, got %v", payload["service"])
		}
		if payload["name"] != "system.load.1m" {
			t.Errorf("expected name=system.load.1m, got %v", payload["name"])
		}
		if payload["metric"] != "0.2" {
			t.Errorf("expected metric=0.2, got %v", payload["metric"])
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for Riemann heartbeat data")
	}
	stdinW.Close()
}
