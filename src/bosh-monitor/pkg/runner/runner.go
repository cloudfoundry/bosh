package runner

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/config"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/director"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/instance"
	hmNats "github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/nats"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginhost"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/processor"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/resurrection"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/server"
)

// pulseInterval is how often the work loop refreshes the HTTP /healthz pulse.
// It must be comfortably smaller than server.PulseTimeout.
const pulseInterval = 10 * time.Second

// natsClient is the subset of *hmNats.Client used by the runner.
// Expressed as an interface so tests can inject a fake without needing a
// live NATS server.
type natsClient interface {
	Connect(cfg hmNats.Config) error
	Subscribe(handler hmNats.MessageHandler) error
	SubscribeDirectorAlerts(handler func(payload string)) error
	Close()
}

// newNATSClient creates the concrete NATS client used in production.
// Tests replace this with a factory that returns a fake.
var newNATSClient = func(logger *slog.Logger) natsClient {
	return hmNats.NewClient(logger)
}

type Runner struct {
	cfg    *config.Config
	logger *slog.Logger

	mu     sync.Mutex
	cancel context.CancelFunc

	natsClient      natsClient
	directorClient  *director.Client
	instanceManager *instance.Manager
	eventProcessor  *processor.EventProcessor
	pluginHost      *pluginhost.Host
	httpServer      *server.Server
	resurrectionMgr *resurrection.Manager
	directorMonitor *hmNats.DirectorMonitor
}

func New(cfg *config.Config, logger *slog.Logger) *Runner {
	return &Runner{
		cfg:    cfg,
		logger: logger,
	}
}

// Stop cancels the runner's context, causing Run to return. It is safe to call
// from a different goroutine than Run, and before Run has started.
func (r *Runner) Stop() {
	r.mu.Lock()
	cancel := r.cancel
	r.mu.Unlock()
	if cancel != nil {
		cancel()
	}
}

func (r *Runner) Run(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	r.mu.Lock()
	r.cancel = cancel
	r.mu.Unlock()

	r.directorClient = director.NewClient(director.Config{
		Endpoint:       r.cfg.Director.Endpoint,
		User:           r.cfg.Director.User,
		Password:       r.cfg.Director.Password,
		ClientID:       r.cfg.Director.ClientID,
		ClientSecret:   r.cfg.Director.ClientSecret,
		DirectorCACert: r.cfg.Director.DirectorCACert,
		UAACACert:      r.cfg.Director.UAACACert,
	}, r.logger)

	r.pluginHost = pluginhost.NewHost(r.logger, nil, r.directorClient)
	r.eventProcessor = processor.NewEventProcessor(r.pluginHost, r.logger)
	r.pluginHost.SetEmitter(r.eventProcessor)

	agentTimeout := time.Duration(r.cfg.Intervals.AgentTimeout) * time.Second
	rogueAgentAlert := time.Duration(r.cfg.Intervals.RogueAgentAlert) * time.Second
	r.instanceManager = instance.NewManager(r.eventProcessor, r.logger, agentTimeout, rogueAgentAlert)

	r.resurrectionMgr = resurrection.NewManager(r.logger)
	r.instanceManager.SetResurrectionChecker(r.resurrectionMgr)

	r.httpServer = server.New(r.cfg.HTTP.Port, r.instanceManager, r.logger)

	if err := r.pluginHost.StartPlugins(r.cfg.Plugins); err != nil {
		return fmt.Errorf("failed to start plugins: %w", err)
	}

	r.eventProcessor.EnablePruning(r.cfg.Intervals.PruneEvents)

	r.natsClient = newNATSClient(r.logger)
	natsCfg := hmNats.Config{
		Endpoint:              r.cfg.Mbus.Endpoint,
		ServerCAPath:          r.cfg.Mbus.ServerCAPath,
		ClientCertificatePath: r.cfg.Mbus.ClientCertificatePath,
		ClientPrivateKeyPath:  r.cfg.Mbus.ClientPrivateKeyPath,
		ConnectionWaitTimeout: r.cfg.Mbus.ConnectionWaitTimeout,
	}
	if err := r.natsClient.Connect(natsCfg); err != nil {
		return fmt.Errorf("failed to connect to NATS: %w", err)
	}

	if err := r.natsClient.Subscribe(func(kind, subject, payload string) {
		r.instanceManager.ProcessEvent(kind, subject, payload)
	}); err != nil {
		return fmt.Errorf("failed to subscribe to NATS: %w", err)
	}

	r.directorMonitor = hmNats.NewDirectorMonitor(r.natsClient, r.eventProcessor, r.logger)
	if err := r.directorMonitor.Subscribe(); err != nil {
		return fmt.Errorf("failed to subscribe to director alerts: %w", err)
	}

	go r.startPeriodicTasks(ctx)

	go func() {
		if err := r.httpServer.Start(); err != nil {
			r.logger.Error("HTTP server error", "error", err)
		}
	}()

	<-ctx.Done()
	r.shutdown()
	return nil
}

func (r *Runner) startPeriodicTasks(ctx context.Context) {
	pollDirector := time.NewTicker(time.Duration(r.cfg.Intervals.PollDirector) * time.Second)
	logStats := time.NewTicker(time.Duration(r.cfg.Intervals.LogStats) * time.Second)
	analyzeAgents := time.NewTicker(time.Duration(r.cfg.Intervals.AnalyzeAgents) * time.Second)
	analyzeInstances := time.NewTicker(time.Duration(r.cfg.Intervals.AnalyzeInstances) * time.Second)
	resurrectionConfig := time.NewTicker(time.Duration(r.cfg.Intervals.ResurrectionConfig) * time.Second)
	// Drive the HTTP /healthz pulse from this loop. If the loop wedges (e.g.
	// blocked on the instance-manager lock), the pulse stops and /healthz goes
	// unhealthy, which is what lets monit restart a stalled monitor.
	pulse := time.NewTicker(pulseInterval)

	defer pollDirector.Stop()
	defer logStats.Stop()
	defer analyzeAgents.Stop()
	defer analyzeInstances.Stop()
	defer resurrectionConfig.Stop()
	defer pulse.Stop()

	r.pollDirector()
	r.fetchResurrectionConfig()

	gracePeriod := time.Duration(r.cfg.Intervals.PollGracePeriod) * time.Second
	graceTimer := time.After(gracePeriod)
	graceExpired := false

	for {
		select {
		case <-ctx.Done():
			return
		case <-graceTimer:
			graceExpired = true
		case <-pollDirector.C:
			r.pollDirector()
		case <-logStats.C:
			r.logStats()
		case <-analyzeAgents.C:
			if graceExpired {
				r.instanceManager.AnalyzeAgents()
			}
		case <-analyzeInstances.C:
			if graceExpired {
				r.instanceManager.AnalyzeInstances()
			}
		case <-resurrectionConfig.C:
			r.fetchResurrectionConfig()
		case <-pulse.C:
			r.httpServer.Pulse()
		}
	}
}

func (r *Runner) pollDirector() {
	r.logger.Info("Fetching deployments from director...")
	if err := r.instanceManager.FetchDeployments(r.directorClient); err != nil {
		r.logger.Error("Failed to fetch deployments", "error", err)
	}
}

func (r *Runner) fetchResurrectionConfig() {
	configs, err := r.directorClient.ResurrectionConfig()
	if err != nil {
		r.logger.Error("Failed to fetch resurrection config", "error", err)
		return
	}
	r.resurrectionMgr.UpdateRules(configs)
}

func (r *Runner) logStats() {
	r.logger.Info("Health Monitor stats",
		"deployments", r.instanceManager.DeploymentsCount(),
		"agents", r.instanceManager.AgentsCount(),
		"instances", r.instanceManager.InstancesCount(),
		"heartbeats_received", r.instanceManager.HeartbeatsReceived(),
		"alerts_processed", r.instanceManager.AlertsProcessed(),
		"events_tracked", r.eventProcessor.EventsCount(),
	)
}

func (r *Runner) shutdown() {
	r.logger.Info("Shutting down...")

	r.eventProcessor.StopPruning()

	if r.pluginHost != nil {
		r.pluginHost.Shutdown()
	}

	if r.httpServer != nil {
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := r.httpServer.Stop(shutdownCtx); err != nil {
			r.logger.Error("HTTP server shutdown error", "error", err)
		}
	}

	if r.natsClient != nil {
		r.natsClient.Close()
	}

	r.logger.Info("Shutdown complete")
}
