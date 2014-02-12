package task_test

import (
	. "bosh/agent/task"
	boshlog "bosh/logger"
	"errors"
	"fmt"
	"github.com/stretchr/testify/assert"

	. "github.com/onsi/ginkgo"
	"time"
)

func testRunningTask(t assert.TestingT, expectedState TaskState, withValue interface{}, withErr error) {
	service := NewAsyncTaskService(boshlog.NewLogger(boshlog.LEVEL_NONE))

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

	if withErr != nil {
		assert.Equal(t, withErr, updatedTask.Error)
	} else {
		assert.NoError(t, updatedTask.Error)
	}
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("running a successful task", func() {
			testRunningTask(GinkgoT(), TaskStateDone, 123, nil)
		})
		It("running a failing task", func() {

			testRunningTask(GinkgoT(), TaskStateFailed, nil, errors.New("Oops"))
		})
		It("start task generates task id", func() {

			var taskFunc = func() (value interface{}, err error) {
				return
			}

			service := NewAsyncTaskService(boshlog.NewLogger(boshlog.LEVEL_NONE))

			for expectedTaskId := 1; expectedTaskId < 20; expectedTaskId++ {
				task := service.StartTask(taskFunc)
				assert.Equal(GinkgoT(), fmt.Sprintf("%d", expectedTaskId), task.Id)
			}
		})
		It("processing many tasks simultaneously", func() {

			taskFunc := func() (value interface{}, err error) {
				time.Sleep(10 * time.Millisecond)
				return
			}

			service := NewAsyncTaskService(boshlog.NewLogger(boshlog.LEVEL_NONE))
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
		})
	})
}
