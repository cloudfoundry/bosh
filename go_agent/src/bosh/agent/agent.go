package agent

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshmbus "bosh/mbus"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"time"
)

type agent struct {
	settings          boshsettings.Service
	logger            boshlog.Logger
	mbusHandler       boshmbus.Handler
	platform          boshplatform.Platform
	actionDispatcher  ActionDispatcher
	heartbeatInterval time.Duration
}

func New(
	settings boshsettings.Service,
	logger boshlog.Logger,
	mbusHandler boshmbus.Handler,
	platform boshplatform.Platform,
	actionDispatcher ActionDispatcher,
) (a agent) {

	a.settings = settings
	a.logger = logger
	a.mbusHandler = mbusHandler
	a.platform = platform
	a.actionDispatcher = actionDispatcher
	a.heartbeatInterval = time.Minute
	return
}

func (a agent) Run() (err error) {
	err = a.platform.StartMonit()
	if err != nil {
		err = bosherr.WrapError(err, "Starting Monit")
		return
	}

	errChan := make(chan error, 1)
	heartbeatChan := make(chan boshmbus.Heartbeat, 1)

	go a.runMbusHandler(errChan)
	go a.generateHeartbeats(heartbeatChan)
	go a.sendHeartbeats(heartbeatChan, errChan)

	select {
	case err = <-errChan:
	}
	return
}

type TaskValue struct {
	AgentTaskId string `json:"agent_task_id"`
	State       string `json:"state"`
}

func (a agent) runMbusHandler(errChan chan error) {
	defer a.logger.HandlePanic("Agent Message Bus Handler")

	err := a.mbusHandler.Run(a.actionDispatcher.Dispatch)
	if err != nil {
		err = bosherr.WrapError(err, "Message Bus Handler")
	}

	errChan <- err
}

func (a agent) generateHeartbeats(heartbeatChan chan boshmbus.Heartbeat) {
	defer a.logger.HandlePanic("Agent Generate Heartbeats")

	tickChan := time.Tick(a.heartbeatInterval)
	heartbeatChan <- getHeartbeat(a.settings, a.platform.GetStatsCollector())
	for {
		select {
		case <-tickChan:
			heartbeatChan <- getHeartbeat(a.settings, a.platform.GetStatsCollector())
		}
	}
}

func (a agent) sendHeartbeats(heartbeatChan chan boshmbus.Heartbeat, errChan chan error) {
	defer a.logger.HandlePanic("Agent Send Heartbeats")

	err := a.mbusHandler.SendPeriodicHeartbeat(heartbeatChan)
	if err != nil {
		err = bosherr.WrapError(err, "Sending Heartbeats")
	}

	errChan <- err
}
