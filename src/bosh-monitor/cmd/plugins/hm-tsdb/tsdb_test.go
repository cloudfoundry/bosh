package main

import (
	"fmt"
	"io"
	"net"
	"strings"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/plugintestutil"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

const cmdTimeout = 3 * time.Second

func startTCPListener(t *testing.T) (string, <-chan string) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	t.Cleanup(func() { ln.Close() })
	ch := make(chan string, 1)
	go func() {
		conn, err := ln.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		data, _ := io.ReadAll(conn)
		ch <- string(data)
	}()
	return ln.Addr().String(), ch
}

// Ruby: "validates options" — missing port → error
func TestTSDBMissingHostPort(t *testing.T) {
	t.Parallel()
	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	_ = plugintestutil.CmdSink(stdoutR)
	errCh := make(chan error, 1)
	go func() { errCh <- pluginlib.RunWithIO(stdinR, stdoutW, runTSDB) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{"host": "localhost"})
	stdinW.Close()
	select {
	case err := <-errCh:
		if err == nil {
			t.Error("expected error for missing port, got nil")
		}
	case <-time.After(3 * time.Second):
		t.Fatal("timed out waiting for plugin error")
	}
}

// Ruby: "sends metrics to TSDB" — heartbeat → "put metric_name ts value deployment=dep..."
func TestTSDBSendsMetrics(t *testing.T) {
	t.Parallel()

	addr, received := startTCPListener(t)
	host, portStr, _ := net.SplitHostPort(addr)
	var port int
	fmt.Sscan(portStr, &port)

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runTSDB) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{"host": host, "port": float64(port)})
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:       "heartbeat",
		ID:         "hb-1",
		Deployment: "mycloud",
		Job:        "web",
		InstanceID: "i1",
		AgentID:    "a1",
		Metrics: []pluginproto.MetricData{
			{
				Name:      "system.load.1m",
				Value:     "0.3",
				Timestamp: 1700000001,
				Tags:      map[string]string{"index": "0"},
			},
		},
	})

	select {
	case data := <-received:
		if !strings.HasPrefix(data, "put system.load.1m") {
			t.Errorf("expected 'put system.load.1m ...', got: %q", data)
		}
		if !strings.Contains(data, "0.3") {
			t.Errorf("expected value 0.3, got: %q", data)
		}
		if !strings.Contains(data, "deployment=mycloud") {
			t.Errorf("expected deployment=mycloud tag, got: %q", data)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for TSDB TCP data")
	}
	stdinW.Close()
}

// Alert events are ignored by TSDB plugin.
func TestTSDBIgnoresAlerts(t *testing.T) {
	t.Parallel()

	addr, received := startTCPListener(t)
	host, portStr, _ := net.SplitHostPort(addr)
	var port int
	fmt.Sscan(portStr, &port)

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runTSDB) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{"host": host, "port": float64(port)})
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{Kind: "alert", ID: "a1", Severity: 2})

	select {
	case <-received:
		t.Error("TSDB plugin should not send data for alert events")
	case <-time.After(500 * time.Millisecond):
		// success
	}
	stdinW.Close()
}
