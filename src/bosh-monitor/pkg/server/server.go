package server

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"sync"
	"time"
)

const PulseTimeout = 180 * time.Second

type InstanceManagerQuerier interface {
	DirectorInitialDeploymentSyncDone() bool
	UnresponsiveAgents() map[string]int
	UnhealthyAgents() map[string]int
	TotalAvailableAgents() map[string]int
	FailingInstances() map[string]int
	StoppedInstances() map[string]int
	UnknownInstances() map[string]int
}

type Server struct {
	instanceManager InstanceManagerQuerier
	logger          *slog.Logger
	httpServer      *http.Server

	mu        sync.Mutex
	heartbeat time.Time
}

// New creates an HTTP server bound to host:port. host defaults to "127.0.0.1"
// (loopback-only) when empty, matching the Ruby implementation. Override for
// integration testing or multi-NIC deployments via the config http.host field.
func New(host string, port int, im InstanceManagerQuerier, logger *slog.Logger) *Server {
	if host == "" {
		host = "127.0.0.1"
	}
	s := &Server{
		instanceManager: im,
		logger:          logger,
		heartbeat:       time.Now(),
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/unresponsive_agents", s.handleAgentEndpoint(func() map[string]int { return s.instanceManager.UnresponsiveAgents() }))
	mux.HandleFunc("/unhealthy_agents", s.handleAgentEndpoint(func() map[string]int { return s.instanceManager.UnhealthyAgents() }))
	mux.HandleFunc("/total_available_agents", s.handleAgentEndpoint(func() map[string]int { return s.instanceManager.TotalAvailableAgents() }))
	mux.HandleFunc("/failing_instances", s.handleAgentEndpoint(func() map[string]int { return s.instanceManager.FailingInstances() }))
	mux.HandleFunc("/stopped_instances", s.handleAgentEndpoint(func() map[string]int { return s.instanceManager.StoppedInstances() }))
	mux.HandleFunc("/unknown_instances", s.handleAgentEndpoint(func() map[string]int { return s.instanceManager.UnknownInstances() }))

	// Built in New() (not Start()) so the fields read by Stop() are never
	// written concurrently with a reader — Start() runs in its own goroutine.
	s.httpServer = &http.Server{
		Addr:    fmt.Sprintf("%s:%d", host, port),
		Handler: mux,
	}

	return s
}

// Start blocks serving HTTP until the server is stopped. It is intended to be
// run in its own goroutine.
func (s *Server) Start() error {
	s.logger.Info("HTTP server starting", "addr", s.httpServer.Addr)
	if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		return fmt.Errorf("HTTP server error: %w", err)
	}
	return nil
}

func (s *Server) Stop(ctx context.Context) error {
	return s.httpServer.Shutdown(ctx)
}

// Pulse records that the monitor's work loop is alive. It must be called
// periodically from the loop whose liveness we want /healthz to reflect. If the
// loop wedges, Pulse stops being called, the recorded time goes stale, and
// /healthz reports unhealthy so monit restarts the process. This mirrors the
// Ruby monitor's reactor-driven pulse — the probe is only meaningful if it is
// driven by the thing actually doing work, not by an independent timer.
func (s *Server) Pulse() {
	s.mu.Lock()
	s.heartbeat = time.Now()
	s.mu.Unlock()
}

func (s *Server) handleHealthz(w http.ResponseWriter, _ *http.Request) {
	s.mu.Lock()
	lastPulse := time.Since(s.heartbeat)
	s.mu.Unlock()

	body := fmt.Sprintf("Last pulse was %v seconds ago", lastPulse.Seconds())

	if lastPulse > PulseTimeout {
		s.logger.Error("PULSE TIMEOUT REACHED: queued jobs are not processing in a timely fashion")
		w.WriteHeader(http.StatusInternalServerError)
	} else {
		w.WriteHeader(http.StatusOK)
	}
	if _, err := w.Write([]byte(body)); err != nil {
		s.logger.Error("Failed to write healthz response", "error", err)
	}
}

func (s *Server) handleAgentEndpoint(getter func() map[string]int) http.HandlerFunc {
	return func(w http.ResponseWriter, _ *http.Request) {
		if !s.instanceManager.DirectorInitialDeploymentSyncDone() {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		data := getter()
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(data); err != nil {
			s.logger.Error("Failed to encode agent endpoint response", "error", err)
		}
	}
}
