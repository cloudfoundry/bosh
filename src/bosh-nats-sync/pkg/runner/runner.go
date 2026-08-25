package runner

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"bosh-nats-sync/pkg/config"
	"bosh-nats-sync/pkg/userssync"
)

type Runner struct {
	config    *config.Config
	logger    *slog.Logger
	sync      *userssync.UsersSync
	cmdRunner userssync.CommandRunner
	stopCh    chan struct{}
	stopped   chan struct{}
}

// Option configures a Runner at construction time.
type Option func(*Runner)

// WithCommandRunner overrides the command runner used to signal nats-server.
// Tests use this to observe SIGHUP reloads without execing a real binary.
func WithCommandRunner(cmdRunner userssync.CommandRunner) Option {
	return func(r *Runner) { r.cmdRunner = cmdRunner }
}

func New(cfg *config.Config, logger *slog.Logger, opts ...Option) *Runner {
	r := &Runner{
		config:  cfg,
		logger:  logger,
		stopCh:  make(chan struct{}),
		stopped: make(chan struct{}),
	}
	for _, opt := range opts {
		opt(r)
	}
	if r.cmdRunner == nil {
		r.cmdRunner = userssync.DefaultCommandRunner
	}
	r.sync = userssync.NewUsersSync(cfg, logger, r.cmdRunner)
	return r
}

func (r *Runner) Run() error {
	defer close(r.stopped)

	r.logger.Info("Nats Sync starting...")

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	// Translate a Stop() (or external signal) into context cancellation so an
	// in-flight Execute — including its connection-wait retry sleep — unwinds
	// promptly instead of blocking shutdown until the pass completes.
	go func() {
		select {
		case <-r.stopCh:
			cancel()
		case <-ctx.Done():
		}
	}()

	// Bootstrap: write the initial NATS config from on-disk subject files
	// immediately, before the director is queried.  This replaces the
	// placeholder token written by pre-start so that health_monitor and the
	// director can authenticate against NATS during director startup.
	if err := r.sync.Bootstrap(); err != nil {
		r.logger.Error("Bootstrap failed, health_monitor may not connect to NATS until next sync", "error", err)
	}

	interval := time.Duration(r.config.Intervals.PollUserSync) * time.Second
	if interval <= 0 {
		return fmt.Errorf("PollUserSync interval must be positive, got %d", r.config.Intervals.PollUserSync)
	}
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-r.stopCh:
			return nil
		case <-ticker.C:
			if err := r.sync.Execute(ctx); err != nil {
				// A context error means we're shutting down, not a fatal sync failure.
				if ctx.Err() != nil {
					return nil
				}
				r.logger.Error("Fatal error during sync, shutting down", "error", err)
				return err
			}
		}
	}
}

func (r *Runner) Stop() {
	select {
	case <-r.stopCh:
	default:
		close(r.stopCh)
	}
	<-r.stopped
}
