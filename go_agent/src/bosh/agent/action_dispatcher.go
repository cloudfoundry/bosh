package agent

import (
	boshaction "bosh/agent/action"
	boshtask "bosh/agent/task"
	bosherr "bosh/errors"
	boshhandler "bosh/handler"
	boshlog "bosh/logger"
)

type ActionDispatcher interface {
	ResumePreviouslyDispatchedTasks()
	Dispatch(req boshhandler.Request) (resp boshhandler.Response)
}

type concreteActionDispatcher struct {
	logger        boshlog.Logger
	taskService   boshtask.Service
	taskManager   boshtask.Manager
	actionFactory boshaction.Factory
	actionRunner  boshaction.Runner
}

func NewActionDispatcher(
	logger boshlog.Logger,
	taskService boshtask.Service,
	taskManager boshtask.Manager,
	actionFactory boshaction.Factory,
	actionRunner boshaction.Runner,
) (dispatcher ActionDispatcher) {
	return concreteActionDispatcher{
		logger:        logger,
		taskService:   taskService,
		taskManager:   taskManager,
		actionFactory: actionFactory,
		actionRunner:  actionRunner,
	}
}

func (dispatcher concreteActionDispatcher) ResumePreviouslyDispatchedTasks() {
	taskInfos, err := dispatcher.taskManager.GetTaskInfos()
	if err != nil {
		// Ignore failure of resuming tasks because there is nothing we can do.
		// API consumers will encounter unknown task id error when they request get_task.
		// Other option is to return an error which will cause agent to restart again
		// which does not help API consumer to determine that agent cannot continue tasks.
		dispatcher.logger.Error("Action Dispatcher", err.Error())
		return
	}

	for _, taskInfo := range taskInfos {
		action, err := dispatcher.actionFactory.Create(taskInfo.Method)
		if err != nil {
			dispatcher.logger.Error("Action Dispatcher", "Unknown action %s", taskInfo.Method)
			dispatcher.taskManager.RemoveTaskInfo(taskInfo.TaskId)
			continue
		}

		taskId := taskInfo.TaskId
		payload := taskInfo.Payload

		task := dispatcher.taskService.CreateTaskWithId(taskId, func() (interface{}, error) {
			return dispatcher.actionRunner.Resume(action, payload)
		}, dispatcher.removeTaskInfo)

		dispatcher.taskService.StartTask(task)
	}
}

func (dispatcher concreteActionDispatcher) Dispatch(req boshhandler.Request) boshhandler.Response {
	action, err := dispatcher.actionFactory.Create(req.Method)

	switch {
	case err != nil:
		dispatcher.logger.Error("Action Dispatcher", "Unknown action %s", req.Method)
		return boshhandler.NewExceptionResponse("unknown message %s", req.Method)

	case action.IsAsynchronous():
		dispatcher.logger.Error("Action Dispatcher", "Running async action %s", req.Method)

		var task boshtask.Task

		runTask := func() (interface{}, error) {
			return dispatcher.actionRunner.Run(action, req.GetPayload())
		}

		// Certain long-running tasks (e.g. configure_networks) must be resumed
		// after agent restart so that API consumers do not need to know
		// if agent is restarted midway through the task.
		if action.IsPersistent() {
			dispatcher.logger.Error("Action Dispatcher", "Running persistent action %s", req.Method)
			task = dispatcher.taskService.CreateTask(runTask, dispatcher.removeTaskInfo)

			taskInfo := boshtask.TaskInfo{
				TaskId:  task.Id,
				Method:  req.Method,
				Payload: req.GetPayload(),
			}

			err = dispatcher.taskManager.AddTaskInfo(taskInfo)
			if err != nil {
				err = bosherr.WrapError(err, "Action Failed %s", req.Method)
				dispatcher.logger.Error("Action Dispatcher", err.Error())
				return boshhandler.NewExceptionResponse(err.Error())
			}
		} else {
			task = dispatcher.taskService.CreateTask(runTask, nil)
		}

		dispatcher.taskService.StartTask(task)

		return boshhandler.NewValueResponse(boshtask.TaskStateValue{
			AgentTaskId: task.Id,
			State:       task.State,
		})

	default:
		dispatcher.logger.Debug("Action Dispatcher", "Running sync action %s", req.Method)

		value, err := dispatcher.actionRunner.Run(action, req.GetPayload())
		if err != nil {
			err = bosherr.WrapError(err, "Action Failed %s", req.Method)
			dispatcher.logger.Error("Action Dispatcher", err.Error())
			return boshhandler.NewExceptionResponse(err.Error())
		}

		return boshhandler.NewValueResponse(value)
	}
}

func (dispatcher concreteActionDispatcher) removeTaskInfo(task boshtask.Task) {
	err := dispatcher.taskManager.RemoveTaskInfo(task.Id)
	if err != nil {
		// There is not much we can do about failing to write state of a finished task.
		// On next agent restart, task will be Resume()d again so it must be idempotent.
		dispatcher.logger.Error("Action Dispatcher", err.Error())
	}
}
