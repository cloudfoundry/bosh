package agent

import (
	"time"

	boshalert "bosh/agent/alert"
	boshas "bosh/agent/applier/applyspec"
	bosherr "bosh/errors"
	boshhandler "bosh/handler"
	boshjobsup "bosh/jobsupervisor"
	boshlog "bosh/logger"
	boshmbus "bosh/mbus"
	boshplatform "bosh/platform"
)

type Agent struct {
	logger            boshlog.Logger
	mbusHandler       boshhandler.Handler
	platform          boshplatform.Platform
	actionDispatcher  ActionDispatcher
	heartbeatInterval time.Duration
	alertBuilder      boshalert.Builder
	jobSupervisor     boshjobsup.JobSupervisor
	specService       boshas.V1Service
}

func New(
	logger boshlog.Logger,
	mbusHandler boshhandler.Handler,
	platform boshplatform.Platform,
	actionDispatcher ActionDispatcher,
	alertBuilder boshalert.Builder,
	jobSupervisor boshjobsup.JobSupervisor,
	specService boshas.V1Service,
	heartbeatInterval time.Duration,
) (a Agent) {
	a.logger = logger
	a.mbusHandler = mbusHandler
	a.platform = platform
	a.actionDispatcher = actionDispatcher
	a.heartbeatInterval = heartbeatInterval
	a.alertBuilder = alertBuilder
	a.jobSupervisor = jobSupervisor
	a.specService = specService
	return
}

func (a Agent) Run() error {
	err := a.platform.StartMonit()
	if err != nil {
		return bosherr.WrapError(err, "Starting Monit")
	}

	errChan := make(chan error, 1)

	a.actionDispatcher.ResumePreviouslyDispatchedTasks()

	go a.subscribeActionDispatcher(errChan)
	go a.generateHeartbeats(errChan)
	go a.jobSupervisor.MonitorJobFailures(a.handleJobFailure)

	select {
	case err = <-errChan:
		return err
	}
}

func (a Agent) subscribeActionDispatcher(errChan chan error) {
	defer a.logger.HandlePanic("Agent Message Bus Handler")

	err := a.mbusHandler.Run(a.actionDispatcher.Dispatch)
	if err != nil {
		err = bosherr.WrapError(err, "Message Bus Handler")
	}

	errChan <- err
}

func (a Agent) generateHeartbeats(errChan chan error) {
	defer a.logger.HandlePanic("Agent Generate Heartbeats")

	// Send initial heartbeat
	a.sendHeartbeat(errChan)

	tickChan := time.Tick(a.heartbeatInterval)

	for {
		select {
		case <-tickChan:
			a.sendHeartbeat(errChan)
		}
	}
}

func (a Agent) sendHeartbeat(errChan chan error) {
	heartbeat, err := a.getHeartbeat()
	if err != nil {
		err = bosherr.WrapError(err, "Building heartbeat")
		errChan <- err
		return
	}

	err = a.mbusHandler.SendToHealthManager("heartbeat", heartbeat)
	if err != nil {
		err = bosherr.WrapError(err, "Sending heartbeat")
		errChan <- err
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
		Vitals:   vitals,
		Job:      spec.JobSpec.Name,
		Index:    spec.Index,
		JobState: a.jobSupervisor.Status(),
	}
	return hb, nil
}

func (a Agent) handleJobFailure(monitAlert boshalert.MonitAlert) error {
	alert, err := a.alertBuilder.Build(monitAlert)
	if err != nil {
		return bosherr.WrapError(err, "Building alert")
	}

	a.mbusHandler.SendToHealthManager("alert", alert)

	return nil
}
