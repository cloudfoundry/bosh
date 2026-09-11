package runner

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/config"
	hmNats "github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/nats"
)

// silentLogger discards all log output during tests.
func silentLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError + 100}))
}

// minimalCfg builds the smallest valid config.Config for a runner test.
func minimalCfg(natsEndpoint string, connTimeout int) *config.Config {
	return &config.Config{
		Mbus: config.MbusConfig{
			Endpoint:              natsEndpoint,
			ConnectionWaitTimeout: connTimeout,
		},
		HTTP: config.HTTPConfig{Port: 0},
		Intervals: config.IntervalsConfig{
			// Large values so periodic tasks never fire during the test.
			PollDirector:       3600,
			PollGracePeriod:    3600,
			LogStats:           3600,
			AnalyzeAgents:      3600,
			AnalyzeInstances:   3600,
			AgentTimeout:       3600,
			RogueAgentAlert:    3600,
			ResurrectionConfig: 3600,
			PruneEvents:        3600,
		},
		Director: config.DirectorConfig{Endpoint: "http://127.0.0.1:1"},
	}
}

// fakeNATSClient is a minimal test double for the natsClient interface.
type fakeNATSClient struct {
	connectErr error
	closed     bool
}

func (f *fakeNATSClient) Connect(_ hmNats.Config) error { return f.connectErr }
func (f *fakeNATSClient) Subscribe(_ hmNats.MessageHandler) error {
	if f.connectErr != nil {
		return f.connectErr
	}
	return nil
}
func (f *fakeNATSClient) SubscribeDirectorAlerts(_ func(string)) error {
	if f.connectErr != nil {
		return f.connectErr
	}
	return nil
}
func (f *fakeNATSClient) Close() { f.closed = true }

// injectNATSFactory replaces newNATSClient with a factory that returns fake
// and restores the original factory on test cleanup.
func injectNATSFactory(t *testing.T, fake natsClient) {
	t.Helper()
	orig := newNATSClient
	newNATSClient = func(_ *slog.Logger) natsClient { return fake }
	t.Cleanup(func() { newNATSClient = orig })
}

// ---------------------------------------------------------------------------
// Ruby: "when NATS calls error handler with a ConnectError" → "shuts down the server"
// Ruby: "raises the last connection error" (when timeout is exceeded)
//
// Go: Run() wraps the NATS connect error as "failed to connect to NATS".
// The runner exits with an error rather than blocking indefinitely.
// ---------------------------------------------------------------------------

func TestRunnerNATSConnectionFails(t *testing.T) {
	fake := &fakeNATSClient{connectErr: errors.New("connection refused")}
	injectNATSFactory(t, fake)

	cfg := minimalCfg("nats://127.0.0.1:4221", 1)
	r := New(cfg, silentLogger())

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err := r.Run(ctx)
	if err == nil {
		t.Fatal("expected error when NATS connection fails, got nil")
	}
	if !strings.Contains(err.Error(), "failed to connect to NATS") {
		t.Errorf("expected 'failed to connect to NATS' in error, got: %v", err)
	}
}

// ---------------------------------------------------------------------------
// Ruby: "when an error occurs while connecting" → "throws the error"
//
// Any error returned by Connect is propagated wrapped as
// "failed to connect to NATS: <original>".
// ---------------------------------------------------------------------------

func TestRunnerNATSConnectErrorPropagated(t *testing.T) {
	sentinel := errors.New("unexpected NATS internal error")
	injectNATSFactory(t, &fakeNATSClient{connectErr: sentinel})

	cfg := minimalCfg("nats://127.0.0.1:4221", 1)
	r := New(cfg, silentLogger())

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err := r.Run(ctx)
	if !errors.Is(err, sentinel) {
		t.Errorf("expected sentinel error to be wrapped in run error, got: %v", err)
	}
}

// ---------------------------------------------------------------------------
// Ruby: "stops the HM server, stops the event loop and logs the error"
// (handle_fatal_error / stop)
//
// Go: cancelling the context causes Run() to call shutdown() and return nil.
// We also verify the NATS client is closed during shutdown.
// ---------------------------------------------------------------------------

func TestRunnerStopsOnContextCancel(t *testing.T) {
	fake := &fakeNATSClient{} // Connect succeeds
	injectNATSFactory(t, fake)

	cfg := minimalCfg("nats://127.0.0.1:4221", 1)
	r := New(cfg, silentLogger())

	ctx, cancel := context.WithCancel(context.Background())

	errCh := make(chan error, 1)
	go func() { errCh <- r.Run(ctx) }()

	// Give the runner time to reach the <-ctx.Done() select, then cancel.
	time.Sleep(100 * time.Millisecond)
	cancel()

	select {
	case err := <-errCh:
		if err != nil {
			t.Errorf("expected nil error on clean shutdown, got: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("runner did not stop after context cancellation")
	}

	if !fake.closed {
		t.Error("expected NATS client to be closed during shutdown")
	}
}

// ---------------------------------------------------------------------------
// Ruby: Stop() == handle_fatal_error calling runner.stop
//
// Calling r.Stop() while Run() is blocking in the select causes Run() to
// exit cleanly (nil error), equivalent to Ruby's runner#stop.
// ---------------------------------------------------------------------------

func TestRunnerStop(t *testing.T) {
	injectNATSFactory(t, &fakeNATSClient{})

	cfg := minimalCfg("nats://127.0.0.1:4221", 1)
	r := New(cfg, silentLogger())

	errCh := make(chan error, 1)
	go func() { errCh <- r.Run(context.Background()) }()

	time.Sleep(100 * time.Millisecond)
	r.Stop()

	select {
	case err := <-errCh:
		if err != nil {
			t.Errorf("expected nil error after Stop(), got: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("runner did not stop after Stop() was called")
	}
}

// ---------------------------------------------------------------------------
// Ruby: plugin startup errors don't prevent the HM from running
//
// StartPlugins logs errors but does not return them; the runner proceeds to
// NATS connect normally.  We verify this non-fatal behaviour by configuring a
// non-existent plugin alongside a fake NATS client and asserting that the
// runner reaches its running state (clean shutdown via context cancel).
// ---------------------------------------------------------------------------

func TestRunnerContinuesWhenPluginStartFails(t *testing.T) {
	injectNATSFactory(t, &fakeNATSClient{})

	cfg := minimalCfg("nats://127.0.0.1:4221", 1)
	cfg.Plugins = []config.PluginConfig{
		{Name: "non_existent_plugin_binary_xyz"},
	}
	r := New(cfg, silentLogger())

	ctx, cancel := context.WithCancel(context.Background())
	errCh := make(chan error, 1)
	go func() { errCh <- r.Run(ctx) }()

	// Give the runner a moment to start up, then shut down.
	time.Sleep(100 * time.Millisecond)
	cancel()

	select {
	case err := <-errCh:
		if err != nil {
			t.Errorf("expected nil: plugin failures are non-fatal, got: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("runner did not stop after context cancellation")
	}
}

// ---------------------------------------------------------------------------
// Ruby: connection_wait_timeout config controls number of attempts
//
// With ConnectionWaitTimeout=1 the Go client makes exactly one Connect
// attempt. We verify via a counting wrapper.
// ---------------------------------------------------------------------------

func TestRunnerNATSUsesConnectionWaitTimeout(t *testing.T) {
	attempts := 0

	counter := &countingNATSClient{
		fakeNATSClient: &fakeNATSClient{},
		attempts:       &attempts,
	}
	injectNATSFactory(t, counter)

	cfg := minimalCfg("nats://127.0.0.1:4221", 1) // timeout=1 → maxAttempts=1
	r := New(cfg, silentLogger())

	ctx, cancel := context.WithCancel(context.Background())
	errCh := make(chan error, 1)
	go func() { errCh <- r.Run(ctx) }()

	time.Sleep(100 * time.Millisecond)
	cancel()
	<-errCh

	if attempts != 1 {
		t.Errorf("expected 1 Connect attempt with timeout=1, got %d", attempts)
	}
}

type countingNATSClient struct {
	*fakeNATSClient
	attempts *int
}

func (c *countingNATSClient) Connect(cfg hmNats.Config) error {
	*c.attempts++
	return c.fakeNATSClient.Connect(cfg)
}

// ---------------------------------------------------------------------------
// Ruby: "should connect using SSL" – Run() passes all Mbus TLS fields to
// the NATS client Config.
// ---------------------------------------------------------------------------

func TestRunnerPassesTLSConfigToNATSClient(t *testing.T) {
	var captured hmNats.Config

	capturer := &capturingNATSClient{capturedCfg: &captured}
	injectNATSFactory(t, capturer)

	cfg := minimalCfg("nats://127.0.0.1:4221", 1)
	cfg.Mbus.ServerCAPath = "/some/ca.pem"
	cfg.Mbus.ClientCertificatePath = "/some/cert.pem"
	cfg.Mbus.ClientPrivateKeyPath = "/some/key.pem"

	r := New(cfg, silentLogger())
	ctx, cancel := context.WithCancel(context.Background())
	errCh := make(chan error, 1)
	go func() { errCh <- r.Run(ctx) }()
	time.Sleep(100 * time.Millisecond)
	cancel()
	<-errCh

	if captured.Endpoint != cfg.Mbus.Endpoint {
		t.Errorf("Endpoint: want %q, got %q", cfg.Mbus.Endpoint, captured.Endpoint)
	}
	if captured.ServerCAPath != cfg.Mbus.ServerCAPath {
		t.Errorf("ServerCAPath: want %q, got %q", cfg.Mbus.ServerCAPath, captured.ServerCAPath)
	}
	if captured.ClientCertificatePath != cfg.Mbus.ClientCertificatePath {
		t.Errorf("ClientCertificatePath: want %q, got %q", cfg.Mbus.ClientCertificatePath, captured.ClientCertificatePath)
	}
	if captured.ClientPrivateKeyPath != cfg.Mbus.ClientPrivateKeyPath {
		t.Errorf("ClientPrivateKeyPath: want %q, got %q", cfg.Mbus.ClientPrivateKeyPath, captured.ClientPrivateKeyPath)
	}
	if captured.ConnectionWaitTimeout != cfg.Mbus.ConnectionWaitTimeout {
		t.Errorf("ConnectionWaitTimeout: want %d, got %d", cfg.Mbus.ConnectionWaitTimeout, captured.ConnectionWaitTimeout)
	}
}

type capturingNATSClient struct {
	capturedCfg *hmNats.Config
}

func (c *capturingNATSClient) Connect(cfg hmNats.Config) error {
	*c.capturedCfg = cfg
	return nil
}
func (c *capturingNATSClient) Subscribe(_ hmNats.MessageHandler) error      { return nil }
func (c *capturingNATSClient) SubscribeDirectorAlerts(_ func(string)) error { return nil }
func (c *capturingNATSClient) Close()                                       {}
