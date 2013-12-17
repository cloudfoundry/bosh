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

func New(settings boshsettings.Service,
	logger boshlog.Logger,
	mbusHandler boshmbus.Handler,
	platform boshplatform.Platform,
	actionDispatcher ActionDispatcher) (a agent) {

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

	go a.subscribeActionDispatcher(errChan)
	go a.generateHeartbeats(errChan)

	select {
	case err = <-errChan:
	}
	return
}

type TaskValue struct {
	AgentTaskId string `json:"agent_task_id"`
	State       string `json:"state"`
}

func (a agent) subscribeActionDispatcher(errChan chan error) {
	defer a.logger.HandlePanic("Agent Message Bus Handler")

	err := a.mbusHandler.SubscribeToDirector(a.actionDispatcher.Dispatch)
	if err != nil {
		err = bosherr.WrapError(err, "Message Bus Handler")
	}

	errChan <- err
}

func (a agent) generateHeartbeats(errChan chan error) {
	defer a.logger.HandlePanic("Agent Generate Heartbeats")

	tickChan := time.Tick(a.heartbeatInterval)

	heartbeat := getHeartbeat(a.settings, a.platform.GetStatsCollector())
	a.sendHeartbeat(heartbeat, errChan)

	for {
		select {
		case <-tickChan:
			heartbeat := getHeartbeat(a.settings, a.platform.GetStatsCollector())
			a.sendHeartbeat(heartbeat, errChan)
		}
	}
}

func (a agent) sendHeartbeat(heartbeat interface{}, errChan chan error) {
	err := a.mbusHandler.SendToHealthManager("heartbeat", heartbeat)
	if err != nil {
		err = bosherr.WrapError(err, "Sending Heartbeat")
	}

	errChan <- err
}
