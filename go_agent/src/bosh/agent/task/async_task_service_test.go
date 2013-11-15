package task

import (
	"errors"
	"fmt"
	"github.com/stretchr/testify/assert"
	"testing"
	"time"
)

func TestRunningASuccessfulTask(t *testing.T) {
	testRunningTask(t, TaskStateDone, nil)
}

func TestRunningAFailingTask(t *testing.T) {
	testRunningTask(t, TaskStateFailed, errors.New("Oops"))
}

func testRunningTask(t *testing.T, expectedState TaskState, withErr error) {
	service := NewAsyncTaskService()

	taskIsFinished := false

	task := service.StartTask(func() (err error) {
		for !taskIsFinished {
		}
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
}

func TestStartTaskGeneratesTaskId(t *testing.T) {
	var taskFunc = func() (err error) {
		return
	}

	service := NewAsyncTaskService()

	for expectedTaskId := 1; expectedTaskId < 20; expectedTaskId++ {
		task := service.StartTask(taskFunc)
		assert.Equal(t, fmt.Sprintf("%d", expectedTaskId), task.Id)
	}
}
