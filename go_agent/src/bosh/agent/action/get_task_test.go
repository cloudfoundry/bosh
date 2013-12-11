package action

import (
	boshtask "bosh/agent/task"
	faketask "bosh/agent/task/fakes"
	boshassert "bosh/assert"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetTaskShouldBeSynchronous(t *testing.T) {
	_, action := buildGetTaskAction()
	assert.False(t, action.IsAsynchronous())
}

func TestGetTaskRunReturnsAFailedTask(t *testing.T) {
	taskService, action := buildGetTaskAction()

	taskService.Tasks = map[string]boshtask.Task{
		"57": boshtask.Task{
			Id:    "found-57-id",
			State: boshtask.TaskStateFailed,
			Error: "Oops we failed...",
		},
	}

	taskValue, err := action.Run("57")
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, taskValue,
		`{"agent_task_id":"found-57-id","state":"failed","exception":"Oops we failed..."}`)
}

func TestGetTaskRunReturnsASuccessfulTask(t *testing.T) {
	taskService, action := buildGetTaskAction()

	taskService.Tasks = map[string]boshtask.Task{
		"57": boshtask.Task{
			Id:    "found-57-id",
			State: boshtask.TaskStateDone,
			Value: "some-task-value",
		},
	}

	taskValue, err := action.Run("57")
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, taskValue,
		`{"agent_task_id":"found-57-id","state":"done","value":"some-task-value"}`)
}

func TestGetTaskRunWhenTaskIsNotFound(t *testing.T) {
	taskService, action := buildGetTaskAction()

	taskService.Tasks = map[string]boshtask.Task{}

	_, err := action.Run("57")
	assert.Error(t, err)
	assert.Equal(t, "Task with id 57 could not be found", err.Error())
}

func buildGetTaskAction() (*faketask.FakeService, getTaskAction) {
	taskService := &faketask.FakeService{}
	return taskService, newGetTask(taskService)
}
