package action

import (
	boshtask "bosh/agent/task"
	faketask "bosh/agent/task/fakes"
	boshassert "bosh/assert"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetTaskShouldBeSynchronous(t *testing.T) {
	_, action := buildGetTaskAction()
	assert.False(t, action.IsAsynchronous())
}

func TestGetTaskRunReturnsARunningTask(t *testing.T) {
	taskService, action := buildGetTaskAction()

	taskService.Tasks = map[string]boshtask.Task{
		"57": boshtask.Task{
			Id:    "found-57-id",
			State: boshtask.TaskStateRunning,
		},
	}

	taskValue, err := action.Run("57")
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, taskValue, `{"agent_task_id":"found-57-id","state":"running"}`)
}

func TestGetTaskRunReturnsAFailedTask(t *testing.T) {
	taskService, action := buildGetTaskAction()

	taskService.Tasks = map[string]boshtask.Task{
		"57": boshtask.Task{
			Id:    "found-57-id",
			State: boshtask.TaskStateFailed,
			Error: errors.New("Oops we failed..."),
		},
	}

	taskValue, err := action.Run("57")
	assert.Error(t, err)
	assert.Equal(t, "Oops we failed...", err.Error())
	boshassert.MatchesJsonString(t, taskValue, `null`)
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
	boshassert.MatchesJsonString(t, taskValue, `"some-task-value"`)
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
