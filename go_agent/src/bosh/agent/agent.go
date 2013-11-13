package agent

import (
	boshaction "bosh/agent/action"
	boshtask "bosh/agent/task"
	boshmbus "bosh/mbus"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"encoding/json"
	"errors"
	"fmt"
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
		case "get_task":
			resp = a.handleGetTask(req)
		}

		return
	}
	errChan <- a.mbusHandler.Run(handlerFunc)
}

func (a agent) handleGetTask(req boshmbus.Request) (resp boshmbus.Response) {
	taskId, err := parseTaskId(req.GetPayload())
	if err != nil {
		resp.Exception = fmt.Sprintf("Error finding task, %s", err.Error())
		return
	}

	task, found := a.taskService.FindTask(taskId)
	if !found {
		resp.Exception = fmt.Sprintf("Task with id %s could not be found", taskId)
		return
	}

	resp.AgentTaskId = task.Id
	resp.State = string(task.State)
	return
}

func parseTaskId(payloadBytes []byte) (taskId string, err error) {
	var payload struct {
		Arguments []string
	}
	err = json.Unmarshal(payloadBytes, &payload)
	if err != nil {
		return
	}

	if len(payload.Arguments) == 0 {
		err = errors.New("not enough arguments")
		return
	}

	taskId = payload.Arguments[0]
	return
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
