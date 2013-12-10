package agent

import (
	boshaction "bosh/agent/action"
	boshtask "bosh/agent/task"
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshmbus "bosh/mbus"
)

type ActionDispatcher interface {
	Dispatch(req boshmbus.Request) (resp boshmbus.Response)
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

func (dispatcher concreteActionDispatcher) Dispatch(req boshmbus.Request) (resp boshmbus.Response) {
	action, err := dispatcher.actionFactory.Create(req.Method)

	switch {
	case err != nil:
		resp = boshmbus.NewExceptionResponse("unknown message %s", req.Method)
		dispatcher.logger.Error("Action Dispatcher", "Unknown action %s", req.Method)

	case action.IsAsynchronous():
		task := dispatcher.taskService.StartTask(func() (value interface{}, err error) {
			value, err = action.Run(req.GetPayload())
			return
		})
		resp = boshmbus.NewValueResponse(TaskValue{
			AgentTaskId: task.Id,
			State:       string(task.State),
		})

	default:
		value, err := action.Run(req.GetPayload())

		if err != nil {
			err = bosherr.WrapError(err, "Action Failed %s", req.Method)
			resp = boshmbus.NewExceptionResponse(err.Error())
			dispatcher.logger.Error("Action Dispatcher", err.Error())
			return
		}
		resp = boshmbus.NewValueResponse(value)
	}
	return
}
