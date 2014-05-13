package agent

import (
	"time"

	boshalert "bosh/agent/alert"
	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
	boshhandler "bosh/handler"
	boshjobsuper "bosh/jobsupervisor"
	boshlog "bosh/logger"
	boshmbus "bosh/mbus"
	boshplatform "bosh/platform"
	boshsyslog "bosh/syslog"
)

type Agent struct {
	logger            boshlog.Logger
	mbusHandler       boshhandler.Handler
	platform          boshplatform.Platform
	actionDispatcher  ActionDispatcher
	heartbeatInterval time.Duration
	alertSender       AlertSender
	jobSupervisor     boshjobsuper.JobSupervisor
	specService       boshas.V1Service
	syslogServer      boshsyslog.Server
}

func New(
	logger boshlog.Logger,
	mbusHandler boshhandler.Handler,
	platform boshplatform.Platform,
	actionDispatcher ActionDispatcher,
	alertSender AlertSender,
	jobSupervisor boshjobsuper.JobSupervisor,
	specService boshas.V1Service,
	syslogServer boshsyslog.Server,
	heartbeatInterval time.Duration,
) (a Agent) {
	a.logger = logger
	a.mbusHandler = mbusHandler
	a.platform = platform
	a.actionDispatcher = actionDispatcher
	a.heartbeatInterval = heartbeatInterval
	a.alertSender = alertSender
	a.jobSupervisor = jobSupervisor
	a.specService = specService
	a.syslogServer = syslogServer
	return
}

func (a Agent) Run() error {
	err := a.platform.StartMonit()
	if err != nil {
		return bosherr.WrapError(err, "Starting Monit")
	}

	errCh := make(chan error, 1)

	a.actionDispatcher.ResumePreviouslyDispatchedTasks()

	go a.subscribeActionDispatcher(errCh)

	go a.generateHeartbeats(errCh)

	go a.jobSupervisor.MonitorJobFailures(a.handleJobFailure(errCh))

	go a.syslogServer.Start(a.handleSyslogMsg(errCh))

	select {
	case err = <-errCh:
		return err
	}
}

func (a Agent) subscribeActionDispatcher(errCh chan error) {
	defer a.logger.HandlePanic("Agent Message Bus Handler")

	err := a.mbusHandler.Run(a.actionDispatcher.Dispatch)
	if err != nil {
		err = bosherr.WrapError(err, "Message Bus Handler")
	}

	errCh <- err
}

func (a Agent) generateHeartbeats(errCh chan error) {
	defer a.logger.HandlePanic("Agent Generate Heartbeats")

	// Send initial heartbeat
	a.sendHeartbeat(errCh)

	tickChan := time.Tick(a.heartbeatInterval)

	for {
		select {
		case <-tickChan:
			a.sendHeartbeat(errCh)
		}
	}
}

func (a Agent) sendHeartbeat(errCh chan error) {
	heartbeat, err := a.getHeartbeat()
	if err != nil {
		err = bosherr.WrapError(err, "Building heartbeat")
		errCh <- err
		return
	}

	err = a.mbusHandler.SendToHealthManager("heartbeat", heartbeat)
	if err != nil {
		err = bosherr.WrapError(err, "Sending heartbeat")
		errCh <- err
	}
}

func (a Agent) getHeartbeat() (boshmbus.Heartbeat, error) {
	vitalsService := a.platform.GetVitalsService()

	vitals, err := vitalsService.Get()
	if err != nil {
		return boshmbus.Heartbeat{}, bosherr.WrapError(err, "Getting job vitals")
	}

	spec, err := a.specService.Get()
	if err != nil {
		return boshmbus.Heartbeat{}, bosherr.WrapError(err, "Getting job spec")
	}

	hb := boshmbus.Heartbeat{
		Job:      spec.JobSpec.Name,
		Index:    spec.Index,
		JobState: a.jobSupervisor.Status(),
		Vitals:   vitals,
	}
	return hb, nil
}

func (a Agent) handleJobFailure(errCh chan error) boshjobsuper.JobFailureHandler {
	return func(monitAlert boshalert.MonitAlert) error {
		err := a.alertSender.SendAlert(monitAlert)
		if err != nil {
			errCh <- bosherr.WrapError(err, "Sending alert")
		}

		return nil
	}
}

func (a Agent) handleSyslogMsg(errCh chan error) boshsyslog.CallbackFunc {
	return func(msg boshsyslog.Msg) {
		err := a.alertSender.SendSSHAlert(msg)
		if err != nil {
			errCh <- bosherr.WrapError(err, "Sending SSH alert")
		}
	}
}
