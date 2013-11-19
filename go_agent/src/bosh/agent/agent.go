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

func New(settings boshsettings.Settings,
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

type TaskValue struct {
	AgentTaskId string `json:"agent_task_id"`
	State       string `json:"state"`
}

func (a agent) runMbusHandler(errChan chan error) {
	handlerFunc := func(req boshmbus.Request) (resp boshmbus.Response) {
		switch req.Method {
		case "get_task", "ping", "get_state", "ssh":
			action := a.actionFactory.Create(req.Method)
			value, err := action.Run(req.GetPayload())
			if err != nil {
				resp = boshmbus.NewExceptionResponse(err.Error())
				return
			}
			resp = boshmbus.NewValueResponse(value)
		case "apply", "logs":
			task := a.taskService.StartTask(func() (err error) {
				action := a.actionFactory.Create(req.Method)
				_, err = action.Run(req.GetPayload())
				return
			})

			resp = boshmbus.NewValueResponse(TaskValue{
				AgentTaskId: task.Id,
				State:       string(task.State),
			})
		default:
			resp = boshmbus.NewExceptionResponse("unknown message %s", req.Method)
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
