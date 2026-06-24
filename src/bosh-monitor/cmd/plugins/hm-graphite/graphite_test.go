package main

import (
	"fmt"
	"io"
	"net"
	"strings"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/plugintestutil"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

const cmdTimeout = 3 * time.Second

// startTCPListener starts a TCP listener and returns its address and a channel
// that receives the first complete message written to any accepted connection.
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

// Ruby: "validates options" — missing host or port → startup error
func TestGraphiteMissingHostPort(t *testing.T) {
	t.Parallel()
	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	_ = plugintestutil.CmdSink(stdoutR)
	errCh := make(chan error, 1)
	go func() { errCh <- pluginlib.RunWithIO(stdinR, stdoutW, runGraphite) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{"host": "localhost"}) // no port
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

// Ruby: "process metrics" — heartbeat with metrics → TCP line "prefix.metric_name value ts"
func TestGraphiteSendsMetrics(t *testing.T) {
	t.Parallel()

	addr, received := startTCPListener(t)
	host, portStr, _ := net.SplitHostPort(addr)
	var port int
	fmt.Sscan(portStr, &port)

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runGraphite) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{"host": host, "port": float64(port)})
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout) // startup

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:       "heartbeat",
		ID:         "hb-1",
		Deployment: "mycloud",
		Job:        "web",
		InstanceID: "inst-1",
		AgentID:    "agent-1",
		Metrics: []pluginproto.MetricData{
			{Name: "system.load.1m", Value: "0.5", Timestamp: 1700000001},
		},
	})

	select {
	case data := <-received:
		if !strings.Contains(data, "mycloud.web.inst-1.agent-1.system_load_1m") {
			t.Errorf("expected metric name with deployment prefix, got: %q", data)
		}
		if !strings.Contains(data, "0.5") {
			t.Errorf("expected metric value 0.5, got: %q", data)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for graphite TCP data")
	}

	stdinW.Close()
}

// Ruby: "validates options" — max_retries=-1337 → invalid (< -1)
// Go: host/port required is the primary validation. Metric prefix customization:
func TestGraphiteCustomPrefix(t *testing.T) {
	t.Parallel()

	addr, received := startTCPListener(t)
	host, portStr, _ := net.SplitHostPort(addr)
	var port int
	fmt.Sscan(portStr, &port)

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()
	cmds := plugintestutil.CmdSink(stdoutR)
	go func() { _ = pluginlib.RunWithIO(stdinR, stdoutW, runGraphite) }()
	plugintestutil.SendInit(t, stdinW, map[string]interface{}{
		"host":   host,
		"port":   float64(port),
		"prefix": "bosh",
	})
	plugintestutil.SkipReady(t, cmds)
	plugintestutil.NextCmdOfType(t, cmds, pluginproto.CommandLog, cmdTimeout)

	plugintestutil.SendEvent(t, stdinW, &pluginproto.EventData{
		Kind:       "heartbeat",
		ID:         "hb-2",
		Deployment: "dep",
		Job:        "job",
		InstanceID: "i1",
		AgentID:    "a1",
		Metrics: []pluginproto.MetricData{
			{Name: "cpu", Value: "10", Timestamp: 1700000002},
		},
	})

	select {
	case data := <-received:
		if !strings.HasPrefix(data, "bosh.dep.job.i1.a1.cpu") {
			t.Errorf("expected prefix 'bosh.' in metric name, got: %q", data)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for graphite TCP data with prefix")
	}
	stdinW.Close()
}
