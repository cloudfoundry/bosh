package server

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

type stubQuerier struct{}

func (stubQuerier) DirectorInitialDeploymentSyncDone() bool { return true }
func (stubQuerier) UnresponsiveAgents() map[string]int      { return nil }
func (stubQuerier) UnhealthyAgents() map[string]int         { return nil }
func (stubQuerier) TotalAvailableAgents() map[string]int    { return nil }
func (stubQuerier) FailingInstances() map[string]int        { return nil }
func (stubQuerier) StoppedInstances() map[string]int        { return nil }
func (stubQuerier) UnknownInstances() map[string]int        { return nil }

func newTestServer() *Server {
	return New("127.0.0.1", 0, stubQuerier{}, slog.New(slog.NewTextHandler(io.Discard, nil)))
}

// TestHealthzUnhealthyWhenPulseStale is the regression test for the decorative
// pulse bug: if the work loop stops calling Pulse(), /healthz must report
// unhealthy so monit restarts the process. Previously the pulse refreshed
// itself unconditionally and could never go stale.
func TestHealthzUnhealthyWhenPulseStale(t *testing.T) {
	s := newTestServer()

	// Simulate a wedged work loop: last pulse was longer ago than the timeout.
	s.mu.Lock()
	s.heartbeat = time.Now().Add(-PulseTimeout - time.Second)
	s.mu.Unlock()

	rec := httptest.NewRecorder()
	s.handleHealthz(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("stale pulse: want 500, got %d", rec.Code)
	}
}

// TestHealthzHealthyAfterPulse verifies a fresh pulse reports healthy.
func TestHealthzHealthyAfterPulse(t *testing.T) {
	s := newTestServer()

	s.mu.Lock()
	s.heartbeat = time.Now().Add(-PulseTimeout - time.Second)
	s.mu.Unlock()

	s.Pulse() // work loop is alive again

	rec := httptest.NewRecorder()
	s.handleHealthz(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("fresh pulse: want 200, got %d", rec.Code)
	}
}
