package agent

import (
	boshaction "bosh/agent/action"
	boshtask "bosh/agent/task"
	boshmbus "bosh/mbus"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"time"
)

type agent struct {
	settings          boshsettings.Settings
	mbusHandler       boshmbus.Handler
	platform          boshplatform.Platform
	taskService       boshtask.Service
	actionFactory     boshaction.Factory
	heartbeatInterval time.Duration
}

func New(
	settings boshsettings.Settings,
	mbusHandler boshmbus.Handler,
	platform boshplatform.Platform,
	taskService boshtask.Service,
	actionFactory boshaction.Factory) (a agent) {

	a.settings = settings
	a.mbusHandler = mbusHandler
	a.platform = platform
	a.taskService = taskService
	a.actionFactory = actionFactory
	a.heartbeatInterval = time.Minute
	return
}

func (a agent) Run() (err error) {

	err = a.platform.StartMonit()
	if err != nil {
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

func (a agent) runMbusHandler(errChan chan error) {
	handlerFunc := func(req boshmbus.Request) (resp boshmbus.Response) {
		switch req.Method {
		case "ping":
			resp.Value = "pong"
		case "apply":
			task := a.taskService.StartTask(func() (err error) {
				action := a.actionFactory.Create(req.Method)
				err = action.Run(req.GetPayload())
				return
			})
			resp.AgentTaskId = task.Id
			resp.State = string(task.State)
		}

		return
	}
	errChan <- a.mbusHandler.Run(handlerFunc)
}

func (a agent) generateHeartbeats(heartbeatChan chan boshmbus.Heartbeat) {
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
	errChan <- a.mbusHandler.SendPeriodicHeartbeat(heartbeatChan)
}
