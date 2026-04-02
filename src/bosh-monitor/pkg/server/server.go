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
	port            int
	instanceManager InstanceManagerQuerier
	logger          *slog.Logger
	httpServer      *http.Server

	mu        sync.Mutex
	heartbeat time.Time
	stopPulse context.CancelFunc
}

func New(port int, im InstanceManagerQuerier, logger *slog.Logger) *Server {
	return &Server{
		port:            port,
		instanceManager: im,
		logger:          logger,
		heartbeat:       time.Now(),
	}
}

func (s *Server) Start() error {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/unresponsive_agents", s.handleAgentEndpoint(func() map[string]int { return s.instanceManager.UnresponsiveAgents() }))
	mux.HandleFunc("/unhealthy_agents", s.handleAgentEndpoint(func() map[string]int { return s.instanceManager.UnhealthyAgents() }))
	mux.HandleFunc("/total_available_agents", s.handleAgentEndpoint(func() map[string]int { return s.instanceManager.TotalAvailableAgents() }))
	mux.HandleFunc("/failing_instances", s.handleAgentEndpoint(func() map[string]int { return s.instanceManager.FailingInstances() }))
	mux.HandleFunc("/stopped_instances", s.handleAgentEndpoint(func() map[string]int { return s.instanceManager.StoppedInstances() }))
	mux.HandleFunc("/unknown_instances", s.handleAgentEndpoint(func() map[string]int { return s.instanceManager.UnknownInstances() }))

	s.httpServer = &http.Server{
		Addr:    fmt.Sprintf("127.0.0.1:%d", s.port),
		Handler: mux,
	}

	ctx, cancel := context.WithCancel(context.Background())
	s.stopPulse = cancel
	go s.pulseLoop(ctx)

	s.logger.Info("HTTP server starting", "port", s.port)
	if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		return fmt.Errorf("HTTP server error: %w", err)
	}
	return nil
}

func (s *Server) Stop(ctx context.Context) error {
	if s.stopPulse != nil {
		s.stopPulse()
	}
	if s.httpServer != nil {
		return s.httpServer.Shutdown(ctx)
	}
	return nil
}

func (s *Server) pulseLoop(ctx context.Context) {
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.mu.Lock()
			s.heartbeat = time.Now()
			s.mu.Unlock()
		}
	}
}

func (s *Server) handleHealthz(w http.ResponseWriter, r *http.Request) {
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
	w.Write([]byte(body))
}

func (s *Server) handleAgentEndpoint(getter func() map[string]int) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !s.instanceManager.DirectorInitialDeploymentSyncDone() {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		data := getter()
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(data)
	}
}
