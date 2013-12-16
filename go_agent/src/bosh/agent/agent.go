package agent

import (
	boshaction "bosh/agent/action"
	boshtask "bosh/agent/task"
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
	taskService       boshtask.Service
	actionFactory     boshaction.Factory
	heartbeatInterval time.Duration
}

func New(
	settings boshsettings.Service,
	logger boshlog.Logger,
	mbusHandler boshmbus.Handler,
	platform boshplatform.Platform,
	taskService boshtask.Service,
	actionFactory boshaction.Factory,
) (a agent) {

	a.settings = settings
	a.logger = logger
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

	handlerFunc := func(req boshmbus.Request) (resp boshmbus.Response) {
		switch req.Method {
		case "get_task", "ping", "get_state", "ssh", "start", "list_disk":
			action := a.actionFactory.Create(req.Method)
			value, err := action.Run(req.GetPayload())

			if err != nil {
				err = bosherr.WrapError(err, "Action Failed %s", req.Method)
				resp = boshmbus.NewExceptionResponse(err.Error())
				a.logger.Error("Agent", err.Error())
				return
			}
			resp = boshmbus.NewValueResponse(value)
		case "apply", "fetch_logs", "stop", "drain", "mount_disk", "unmount_disk", "migrate_disk":
			task := a.taskService.StartTask(func() (value interface{}, err error) {
				action := a.actionFactory.Create(req.Method)
				value, err = action.Run(req.GetPayload())
				return
			})

			resp = boshmbus.NewValueResponse(TaskValue{
				AgentTaskId: task.Id,
				State:       string(task.State),
			})
		default:
			resp = boshmbus.NewExceptionResponse("unknown message %s", req.Method)
			a.logger.Error("Agent", "Unknown action %s", req.Method)
		}

		return
	}

	err := a.mbusHandler.Run(handlerFunc)
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
