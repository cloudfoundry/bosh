package action

import (
	boshtask "bosh/agent/task"
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetTaskRunReturns(t *testing.T) {
	settings, fs, platform, taskService := getFakeFactoryDependencies()
	taskService.Tasks = map[string]boshtask.Task{
		"57": boshtask.Task{
			Id:    "found-57-id",
			State: boshtask.TaskStateFailed,
		},
	}

	factory := NewFactory(settings, fs, platform, taskService)
	getTask := factory.Create("get_task")

	taskValue, err := getTask.Run([]byte(`{"arguments":["57"]}`))
	assert.NoError(t, err)

	taskBytes, _ := json.Marshal(taskValue)
	assert.Equal(t, `{"agent_task_id":"found-57-id","state":"failed"}`, string(taskBytes))
}

func TestGetTaskRunWhenTaskIsNotFound(t *testing.T) {
	settings, fs, platform, taskService := getFakeFactoryDependencies()
	taskService.Tasks = map[string]boshtask.Task{}

	factory := NewFactory(settings, fs, platform, taskService)
	getTask := factory.Create("get_task")

	_, err := getTask.Run([]byte(`{"arguments":["57"]}`))
	assert.Error(t, err)
	assert.Equal(t, "Task with id 57 could not be found", err.Error())
}

func TestGetTaskRunWhenPayloadDoesNotHaveTaskId(t *testing.T) {
	settings, fs, platform, taskService := getFakeFactoryDependencies()
	taskService.Tasks = map[string]boshtask.Task{}

	factory := NewFactory(settings, fs, platform, taskService)
	getTask := factory.Create("get_task")

	_, err := getTask.Run([]byte(`{"arguments":[]}`))
	assert.Error(t, err)
	assert.Equal(t, "Error finding task: not enough arguments", err.Error())
}
