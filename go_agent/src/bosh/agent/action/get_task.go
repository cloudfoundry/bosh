package action

import (
	boshtask "bosh/agent/task"
	bosherr "bosh/errors"
	"encoding/json"
	"errors"
)

type getTaskAction struct {
	taskService boshtask.Service
}

func newGetTask(taskService boshtask.Service) (getTask getTaskAction) {
	getTask.taskService = taskService
	return
}

func (a getTaskAction) IsAsynchronous() bool {
	return false
}

func (a getTaskAction) Run(taskId string) (value interface{}, err error) {
	task, found := a.taskService.FindTask(taskId)
	if !found {
		err = bosherr.New("Task with id %s could not be found", taskId)
		return
	}

	if task.State == boshtask.TaskStateRunning {
		value = map[string]string{
			"agent_task_id": task.Id,
			"state":         "running",
		}
		return
	}

	value = task.Value
	err = task.Error
	return
}

func parseTaskId(payloadBytes []byte) (taskId string, err error) {
	var payload struct {
		Arguments []string
	}
	err = json.Unmarshal(payloadBytes, &payload)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling payload")
		return
	}

	if len(payload.Arguments) == 0 {
		err = errors.New("Not enough arguments")
		return
	}

	taskId = payload.Arguments[0]
	return
}
