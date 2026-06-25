package runner

import (
	"fmt"
	"log/slog"
	"time"

	"bosh-nats-sync/pkg/config"
	"bosh-nats-sync/pkg/userssync"
)

type Runner struct {
	config        *config.Config
	logger        *slog.Logger
	stopCh        chan struct{}
	stopped       chan struct{}
	commandRunner userssync.CommandRunner
}

func New(cfg *config.Config, logger *slog.Logger) *Runner {
	return &Runner{
		config:  cfg,
		logger:  logger,
		stopCh:  make(chan struct{}),
		stopped: make(chan struct{}),
	}
}

func NewWithCommandRunner(cfg *config.Config, logger *slog.Logger, cmdRunner userssync.CommandRunner) *Runner {
	return &Runner{
		config:        cfg,
		logger:        logger,
		stopCh:        make(chan struct{}),
		stopped:       make(chan struct{}),
		commandRunner: cmdRunner,
	}
}

func (r *Runner) Run() error {
	defer close(r.stopped)

	r.logger.Info("Nats Sync starting...")

	cmdRunner := r.commandRunner
	if cmdRunner == nil {
		cmdRunner = userssync.DefaultCommandRunner
	}

	// Bootstrap: write the initial NATS config from on-disk subject files
	// immediately, before the director is queried.  This replaces the
	// placeholder token written by pre-start so that health_monitor and the
	// director can authenticate against NATS during director startup.
	r.bootstrapNATSConfig(cmdRunner)

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
			r.syncNATSUsers(cmdRunner)
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

func (r *Runner) bootstrapNATSConfig(cmdRunner userssync.CommandRunner) {
	sync := &userssync.UsersSync{
		NATSConfigFilePath:   r.config.NATS.ConfigFilePath,
		BoshConfig:           r.config.Director,
		NATSServerExecutable: r.config.NATS.NATSServerExecutable,
		NATSServerPIDFile:    r.config.NATS.NATSServerPIDFile,
		Logger:               r.logger,
		CommandRunner:        cmdRunner,
	}
	if err := sync.Bootstrap(); err != nil {
		r.logger.Error("Bootstrap failed, health_monitor may not connect to NATS until next sync", "error", err)
	}
}

func (r *Runner) syncNATSUsers(cmdRunner userssync.CommandRunner) {
	sync := &userssync.UsersSync{
		NATSConfigFilePath:   r.config.NATS.ConfigFilePath,
		BoshConfig:           r.config.Director,
		NATSServerExecutable: r.config.NATS.NATSServerExecutable,
		NATSServerPIDFile:    r.config.NATS.NATSServerPIDFile,
		Logger:               r.logger,
		CommandRunner:        cmdRunner,
	}

	if err := sync.Execute(); err != nil {
		r.logger.Error(err.Error())
		r.logger.Error("Fatal error during sync, shutting down")
		go r.Stop()
	}
}
