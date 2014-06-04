package action

import (
	"errors"

	boshtask "bosh/agent/task"
	bosherr "bosh/errors"
)

type GetTaskAction struct {
	taskService boshtask.Service
}

func NewGetTask(taskService boshtask.Service) (getTask GetTaskAction) {
	getTask.taskService = taskService
	return
}

func (a GetTaskAction) IsAsynchronous() bool {
	return false
}

func (a GetTaskAction) IsPersistent() bool {
	return false
}

func (a GetTaskAction) Run(taskID string) (interface{}, error) {
	task, found := a.taskService.FindTaskWithID(taskID)
	if !found {
		return nil, bosherr.New("Task with id %s could not be found", taskID)
	}

	if task.State == boshtask.TaskStateRunning {
		return boshtask.TaskStateValue{
			AgentTaskID: task.ID,
			State:       task.State,
		}, nil
	}

	if task.Error != nil {
		return task.Value, bosherr.WrapError(task.Error, "Task %s result", taskID)
	}

	return task.Value, nil
}

func (a GetTaskAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a GetTaskAction) Cancel() error {
	return errors.New("not supported")
}
