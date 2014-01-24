package agent

import (
	boshaction "bosh/agent/action"
	boshtask "bosh/agent/task"
	bosherr "bosh/errors"
	boshhandler "bosh/handler"
	boshlog "bosh/logger"
)

type ActionDispatcher interface {
	Dispatch(req boshhandler.Request) (resp boshhandler.Response)
}

type concreteActionDispatcher struct {
	logger        boshlog.Logger
	taskService   boshtask.Service
	actionFactory boshaction.Factory
	actionRunner  boshaction.Runner
}

func NewActionDispatcher(logger boshlog.Logger, taskService boshtask.Service, actionFactory boshaction.Factory, actionRunner boshaction.Runner) (dispatcher ActionDispatcher) {
	return concreteActionDispatcher{
		logger:        logger,
		taskService:   taskService,
		actionFactory: actionFactory,
		actionRunner:  actionRunner,
	}
}

func (dispatcher concreteActionDispatcher) Dispatch(req boshhandler.Request) (resp boshhandler.Response) {
	action, err := dispatcher.actionFactory.Create(req.Method)

	switch {
	case err != nil:
		resp = boshhandler.NewExceptionResponse("unknown message %s", req.Method)
		dispatcher.logger.Error("Action Dispatcher", "Unknown action %s", req.Method)

	case action.IsAsynchronous():
		task := dispatcher.taskService.StartTask(func() (value interface{}, err error) {
			value, err = dispatcher.actionRunner.Run(action, req.GetPayload())
			return
		})

		resp = boshhandler.NewValueResponse(boshtask.TaskStateValue{
			AgentTaskId: task.Id,
			State:       task.State,
		})

	default:
		value, err := dispatcher.actionRunner.Run(action, req.GetPayload())

		if err != nil {
			err = bosherr.WrapError(err, "Action Failed %s", req.Method)
			resp = boshhandler.NewExceptionResponse(err.Error())
			dispatcher.logger.Error("Action Dispatcher", err.Error())
			return
		}
		resp = boshhandler.NewValueResponse(value)
	}
	return
}
