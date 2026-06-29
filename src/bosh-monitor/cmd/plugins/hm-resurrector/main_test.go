package main

import (
	"bufio"
	"encoding/json"
	"io"
	"strings"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

// cmdSink continuously reads JSON commands from r and sends them to the
// returned channel. The goroutine exits when r is closed. Using a sink
// prevents io.Pipe from blocking when the test does not read every command
// (e.g. the emit_alert that follows scan_and_fix).
func cmdSink(r io.Reader) <-chan *pluginproto.Command {
	ch := make(chan *pluginproto.Command, 100)
	go func() {
		scanner := bufio.NewScanner(r)
		for scanner.Scan() {
			var cmd pluginproto.Command
			if err := json.Unmarshal(scanner.Bytes(), &cmd); err == nil {
				ch <- &cmd
			}
		}
		close(ch)
	}()
	return ch
}

func sendEnvelope(t *testing.T, w io.Writer, env *pluginproto.Envelope) {
	t.Helper()
	data, err := json.Marshal(env)
	if err != nil {
		t.Fatalf("marshal envelope: %v", err)
	}
	if _, err := w.Write(append(data, '\n')); err != nil {
		t.Logf("write envelope (%s): %v", env.Type, err)
	}
}

func nextCmd(t *testing.T, ch <-chan *pluginproto.Command, timeout time.Duration) *pluginproto.Command {
	t.Helper()
	select {
	case cmd, ok := <-ch:
		if !ok {
			t.Fatal("command channel closed unexpectedly")
		}
		return cmd
	case <-time.After(timeout):
		t.Fatalf("timed out after %v waiting for a command from the plugin (possible deadlock)", timeout)
		return nil
	}
}

func nextCmdOfType(t *testing.T, ch <-chan *pluginproto.Command, want string, timeout time.Duration) *pluginproto.Command {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			break
		}
		cmd := nextCmd(t, ch, remaining)
		if cmd.Cmd == want {
			return cmd
		}
		t.Logf("skipping unexpected command %q while waiting for %q", cmd.Cmd, want)
	}
	t.Fatalf("did not receive command %q within %v", want, timeout)
	return nil
}

// TestResurrectorNoDeadlock drives the resurrector plugin end-to-end via
// pluginlib.RunWithIO and verifies that:
//
//  1. After receiving a deployment_health alert the plugin emits an http_get.
//  2. After receiving the http_response (200, empty task list) the plugin
//     emits a PUT http_request to /deployments/.../scan_and_fix.
//
// Before the goroutine fix, the plugin's main event loop was blocked inside
// the inner `select` waiting for respCh, which meant the HTTP response that
// arrived via the `events` channel could never be routed to respCh. The
// 10-second timeout would fire, set alreadyQueued=true, and suppress
// resurrection. This test catches that regression.
func TestResurrectorNoDeadlock(t *testing.T) {
	t.Parallel()

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()

	errCh := make(chan error, 1)
	go func() {
		errCh <- pluginlib.RunWithIO(stdinR, stdoutW, runResurrector)
	}()

	// Drain all commands from stdout continuously so pluginlib never blocks.
	cmds := cmdSink(stdoutR)
	const timeout = 5 * time.Second

	// 1. Send the init envelope.
	sendEnvelope(t, stdinW, pluginproto.NewInitEnvelope(map[string]interface{}{}))

	// 2. Read "ready".
	if cmd := nextCmdOfType(t, cmds, pluginproto.CommandReady, timeout); cmd == nil {
		t.Fatal("expected ready")
	}

	// 3. Read the startup log ("Resurrector is running...").
	nextCmdOfType(t, cmds, pluginproto.CommandLog, timeout)

	// 4. Send a deployment_health alert.
	deployment := "simple"
	jobs := map[string][]string{"foobar": {"instance-id-1"}}
	ed := &pluginproto.EventData{
		Kind:              "alert",
		ID:                "alert-1",
		Category:          "deployment_health",
		Deployment:        deployment,
		JobsToInstanceIDs: jobs,
		CreatedAt:         time.Now().Unix(),
	}
	sendEnvelope(t, stdinW, pluginproto.NewEventEnvelope(ed))

	// 5. Read the http_get command (task-check).
	httpGet := nextCmdOfType(t, cmds, pluginproto.CommandHTTPGet, timeout)
	reqID := httpGet.ID
	if reqID == "" {
		t.Fatal("http_get had empty ID")
	}
	if !strings.Contains(httpGet.URL, "/tasks") {
		t.Fatalf("http_get URL %q does not contain /tasks", httpGet.URL)
	}

	// 6. Reply to the http_get with an empty task list (200).
	//    Without the goroutine fix the plugin's main loop is blocked here and
	//    this response never gets routed — causing the 10-second timeout and
	//    alreadyQueued=true suppression of resurrection.
	sendEnvelope(t, stdinW, pluginproto.NewHTTPResponseEnvelope(reqID, 200, "[]"))

	// 7. Read the http_request PUT to scan_and_fix — only arrives if the fix
	//    is in place and the goroutine correctly handles the response.
	scanCmd := nextCmdOfType(t, cmds, pluginproto.CommandHTTPRequest, timeout)
	if scanCmd.Method != "PUT" {
		t.Fatalf("expected PUT, got %q", scanCmd.Method)
	}
	wantPath := "/deployments/" + deployment + "/scan_and_fix"
	if !strings.Contains(scanCmd.URL, wantPath) {
		t.Fatalf("scan_and_fix URL %q does not contain %q", scanCmd.URL, wantPath)
	}

	// 8. Shut down.
	sendEnvelope(t, stdinW, pluginproto.NewShutdownEnvelope())
	select {
	case err := <-errCh:
		if err != nil {
			t.Fatalf("plugin exited with error: %v", err)
		}
	case <-time.After(timeout):
		t.Fatal("timed out waiting for plugin to exit after shutdown")
	}
}

// TestResurrectorSkipsAlreadyQueuedTask verifies that when the tasks endpoint
// returns a "scan and fix" task the plugin does NOT send another scan_and_fix.
func TestResurrectorSkipsAlreadyQueuedTask(t *testing.T) {
	t.Parallel()

	stdinR, stdinW := io.Pipe()
	stdoutR, stdoutW := io.Pipe()

	errCh := make(chan error, 1)
	go func() {
		errCh <- pluginlib.RunWithIO(stdinR, stdoutW, runResurrector)
	}()

	cmds := cmdSink(stdoutR)
	const timeout = 5 * time.Second

	sendEnvelope(t, stdinW, pluginproto.NewInitEnvelope(map[string]interface{}{}))
	nextCmdOfType(t, cmds, pluginproto.CommandReady, timeout)
	nextCmdOfType(t, cmds, pluginproto.CommandLog, timeout)

	deployment := "simple"
	jobs := map[string][]string{"foobar": {"instance-id-1"}}
	ed := &pluginproto.EventData{
		Kind:              "alert",
		ID:                "alert-2",
		Category:          "deployment_health",
		Deployment:        deployment,
		JobsToInstanceIDs: jobs,
		CreatedAt:         time.Now().Unix(),
	}
	sendEnvelope(t, stdinW, pluginproto.NewEventEnvelope(ed))

	httpGet := nextCmdOfType(t, cmds, pluginproto.CommandHTTPGet, timeout)

	// Reply with a task list that includes "scan and fix".
	taskBody := `[{"description":"scan and fix","state":"queued"}]`
	sendEnvelope(t, stdinW, pluginproto.NewHTTPResponseEnvelope(httpGet.ID, 200, taskBody))

	// Expect an "already queued" log, and must NOT see a PUT http_request.
	found := false
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			break
		}
		select {
		case cmd, ok := <-cmds:
			if !ok {
				t.Fatal("command channel closed unexpectedly")
			}
			if cmd.Cmd == pluginproto.CommandHTTPRequest && cmd.Method == "PUT" {
				t.Fatal("plugin should NOT have sent a PUT scan_and_fix when task already queued")
			}
			if cmd.Cmd == pluginproto.CommandLog && strings.Contains(cmd.Message, "already queued") {
				found = true
			}
		case <-time.After(remaining):
		}
		if found {
			break
		}
	}
	if !found {
		t.Fatal("expected 'already queued' log message, did not receive it")
	}

	sendEnvelope(t, stdinW, pluginproto.NewShutdownEnvelope())
	select {
	case err := <-errCh:
		if err != nil {
			t.Fatalf("plugin exited with error: %v", err)
		}
	case <-time.After(timeout):
		t.Fatal("timed out waiting for plugin to exit")
	}
}
