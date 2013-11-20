package task

import (
	"errors"
	"fmt"
	"github.com/stretchr/testify/assert"
	"testing"
	"time"
)

func TestRunningASuccessfulTask(t *testing.T) {
	testRunningTask(t, TaskStateDone, 123, nil)
}

func TestRunningAFailingTask(t *testing.T) {
	testRunningTask(t, TaskStateFailed, nil, errors.New("Oops"))
}

func testRunningTask(t *testing.T, expectedState TaskState, withValue interface{}, withErr error) {
	service := NewAsyncTaskService()

	taskIsFinished := false

	task := service.StartTask(func() (value interface{}, err error) {
		for !taskIsFinished {
		}
		value = withValue
		err = withErr
		return
	})

	assert.Equal(t, "1", task.Id)
	assert.Equal(t, "running", task.State)

	taskIsFinished = true

	updatedTask, _ := service.FindTask(task.Id)

	for updatedTask.State != expectedState {
		time.Sleep(time.Nanosecond)
		updatedTask, _ = service.FindTask(task.Id)
	}
	assert.Equal(t, expectedState, updatedTask.State)
	assert.Equal(t, withValue, updatedTask.Value)
}

func TestStartTaskGeneratesTaskId(t *testing.T) {
	var taskFunc = func() (value interface{}, err error) {
		return
	}

	service := NewAsyncTaskService()

	for expectedTaskId := 1; expectedTaskId < 20; expectedTaskId++ {
		task := service.StartTask(taskFunc)
		assert.Equal(t, fmt.Sprintf("%d", expectedTaskId), task.Id)
	}
}

func TestProcessingManyTasksSimultaneously(t *testing.T) {
	taskFunc := func() (value interface{}, err error) {
		time.Sleep(10 * time.Millisecond)
		return
	}

	service := NewAsyncTaskService()
	ids := []string{}

	for id := 1; id < 200; id++ {
		ids = append(ids, fmt.Sprintf("%d", id))
		go service.StartTask(taskFunc)
	}

	for {
		allDone := true

		for _, id := range ids {
			task, _ := service.FindTask(id)
			if task.State != TaskStateDone {
				allDone = false
				break
			}
		}

		if allDone {
			break
		}

		time.Sleep(200 * time.Millisecond)
	}
}
