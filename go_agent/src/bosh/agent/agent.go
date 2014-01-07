package agent

import (
	boshalert "bosh/agent/alert"
	bosherr "bosh/errors"
	boshjobsup "bosh/jobsupervisor"
	boshlog "bosh/logger"
	boshmbus "bosh/mbus"
	boshplatform "bosh/platform"
	"time"
)

type agent struct {
	logger            boshlog.Logger
	mbusHandler       boshmbus.Handler
	platform          boshplatform.Platform
	actionDispatcher  ActionDispatcher
	heartbeatInterval time.Duration
	alertBuilder      boshalert.Builder
	jobSupervisor     boshjobsup.JobSupervisor
}

func New(logger boshlog.Logger,
	mbusHandler boshmbus.Handler,
	platform boshplatform.Platform,
	actionDispatcher ActionDispatcher,
	alertBuilder boshalert.Builder,
	jobSupervisor boshjobsup.JobSupervisor,
) (a agent) {

	a.logger = logger
	a.mbusHandler = mbusHandler
	a.platform = platform
	a.actionDispatcher = actionDispatcher
	a.heartbeatInterval = time.Minute
	a.alertBuilder = alertBuilder
	a.jobSupervisor = jobSupervisor
	return
}

func (a agent) Run() (err error) {
	err = a.platform.StartMonit()
	if err != nil {
		err = bosherr.WrapError(err, "Starting Monit")
		return
	}

	errChan := make(chan error, 1)

	go a.subscribeActionDispatcher(errChan)
	go a.generateHeartbeats(errChan)
	go a.jobSupervisor.MonitorJobFailures(a.handleJobFailure)

	select {
	case err = <-errChan:
	}
	return
}

func (a agent) subscribeActionDispatcher(errChan chan error) {
	defer a.logger.HandlePanic("Agent Message Bus Handler")

	err := a.mbusHandler.Run(a.actionDispatcher.Dispatch)
	if err != nil {
		err = bosherr.WrapError(err, "Message Bus Handler")
	}

	errChan <- err
}

func (a agent) generateHeartbeats(errChan chan error) {
	defer a.logger.HandlePanic("Agent Generate Heartbeats")

	tickChan := time.Tick(a.heartbeatInterval)

	a.sendHeartbeat(errChan)
	for {
		select {
		case <-tickChan:
			a.sendHeartbeat(errChan)
		}
	}
}

func (a agent) sendHeartbeat(errChan chan error) {
	heartbeat := a.getHeartbeat()
	err := a.mbusHandler.SendToHealthManager("heartbeat", heartbeat)
	if err != nil {
		err = bosherr.WrapError(err, "Sending Heartbeat")
		errChan <- err
	}
}

func (a agent) getHeartbeat() (hb boshmbus.Heartbeat) {
	vitalsService := a.platform.GetVitalsService()

	vitals, err := vitalsService.Get()
	if err != nil {
		return
	}

	hb.Vitals = vitals
	return
}

func (a agent) handleJobFailure(monitAlert boshalert.MonitAlert) (err error) {
	alert, err := a.alertBuilder.Build(monitAlert)
	if err != nil {
		err = bosherr.WrapError(err, "Building alert")
		return
	}
	a.mbusHandler.SendToHealthManager("alert", alert)

	return
}
