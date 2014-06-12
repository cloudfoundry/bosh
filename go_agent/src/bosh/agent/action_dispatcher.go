package agent

import (
	boshaction "bosh/agent/action"
	boshtask "bosh/agent/task"
	bosherr "bosh/errors"
	boshhandler "bosh/handler"
	boshlog "bosh/logger"
)

const actionDispatcherLogTag = "Action Dispatcher"

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
		dispatcher.logger.Error(actionDispatcherLogTag, err.Error())
		return
	}

	for _, taskInfo := range taskInfos {
		action, err := dispatcher.actionFactory.Create(taskInfo.Method)
		if err != nil {
			dispatcher.logger.Error(actionDispatcherLogTag, "Unknown action %s", taskInfo.Method)
			dispatcher.taskManager.RemoveTaskInfo(taskInfo.TaskID)
			continue
		}

		taskID := taskInfo.TaskID
		payload := taskInfo.Payload

		task := dispatcher.taskService.CreateTaskWithID(
			taskID,
			func() (interface{}, error) { return dispatcher.actionRunner.Resume(action, payload) },
			func(_ boshtask.Task) error { return action.Cancel() },
			dispatcher.removeTaskInfo,
		)

		dispatcher.taskService.StartTask(task)
	}
}

func (dispatcher concreteActionDispatcher) Dispatch(req boshhandler.Request) boshhandler.Response {
	action, err := dispatcher.actionFactory.Create(req.Method)
	if err != nil {
		dispatcher.logger.Error(actionDispatcherLogTag, "Unknown action %s", req.Method)
		return boshhandler.NewExceptionResponse(bosherr.New("unknown message %s", req.Method))
	}

	if action.IsAsynchronous() {
		return dispatcher.dispatchAsynchronousAction(action, req)
	}

	return dispatcher.dispatchSynchronousAction(action, req)
}

func (dispatcher concreteActionDispatcher) dispatchAsynchronousAction(
	action boshaction.Action,
	req boshhandler.Request,
) boshhandler.Response {
	dispatcher.logger.Info(actionDispatcherLogTag, "Running async action %s", req.Method)

	var task boshtask.Task
	var err error

	runTask := func() (interface{}, error) {
		return dispatcher.actionRunner.Run(action, req.GetPayload())
	}

	cancelTask := func(_ boshtask.Task) error { return action.Cancel() }

	// Certain long-running tasks (e.g. configure_networks) must be resumed
	// after agent restart so that API consumers do not need to know
	// if agent is restarted midway through the task.
	if action.IsPersistent() {
		dispatcher.logger.Info(actionDispatcherLogTag, "Running persistent action %s", req.Method)
		task, err = dispatcher.taskService.CreateTask(runTask, cancelTask, dispatcher.removeTaskInfo)
		if err != nil {
			err = bosherr.WrapError(err, "Create Task Failed %s", req.Method)
			dispatcher.logger.Error(actionDispatcherLogTag, err.Error())
			return boshhandler.NewExceptionResponse(err)
		}

		taskInfo := boshtask.TaskInfo{
			TaskID:  task.ID,
			Method:  req.Method,
			Payload: req.GetPayload(),
		}

		err = dispatcher.taskManager.AddTaskInfo(taskInfo)
		if err != nil {
			err = bosherr.WrapError(err, "Action Failed %s", req.Method)
			dispatcher.logger.Error(actionDispatcherLogTag, err.Error())
			return boshhandler.NewExceptionResponse(err)
		}
	} else {
		task, err = dispatcher.taskService.CreateTask(runTask, cancelTask, nil)
		if err != nil {
			err = bosherr.WrapError(err, "Create Task Failed %s", req.Method)
			dispatcher.logger.Error(actionDispatcherLogTag, err.Error())
			return boshhandler.NewExceptionResponse(err)
		}
	}

	dispatcher.taskService.StartTask(task)

	return boshhandler.NewValueResponse(boshtask.TaskStateValue{
		AgentTaskID: task.ID,
		State:       task.State,
	})
}

func (dispatcher concreteActionDispatcher) dispatchSynchronousAction(
	action boshaction.Action,
	req boshhandler.Request,
) boshhandler.Response {
	dispatcher.logger.Info(actionDispatcherLogTag, "Running sync action %s", req.Method)

	value, err := dispatcher.actionRunner.Run(action, req.GetPayload())
	if err != nil {
		err = bosherr.WrapError(err, "Action Failed %s", req.Method)
		dispatcher.logger.Error(actionDispatcherLogTag, err.Error())
		return boshhandler.NewExceptionResponse(err)
	}

	return boshhandler.NewValueResponse(value)
}

func (dispatcher concreteActionDispatcher) removeTaskInfo(task boshtask.Task) {
	err := dispatcher.taskManager.RemoveTaskInfo(task.ID)
	if err != nil {
		// There is not much we can do about failing to write state of a finished task.
		// On next agent restart, task will be Resume()d again so it must be idempotent.
		dispatcher.logger.Error(actionDispatcherLogTag, err.Error())
	}
}
