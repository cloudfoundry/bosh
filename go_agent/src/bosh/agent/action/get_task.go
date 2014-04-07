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

func (a GetTaskAction) Run(taskID string) (value interface{}, err error) {
	task, found := a.taskService.FindTaskWithID(taskID)
	if !found {
		err = bosherr.New("Task with id %s could not be found", taskID)
		return
	}

	if task.State == boshtask.TaskStateRunning {
		value = boshtask.TaskStateValue{
			AgentTaskID: task.ID,
			State:       task.State,
		}
		return
	}

	value = task.Value
	err = task.Error
	return
}

func (a GetTaskAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}
