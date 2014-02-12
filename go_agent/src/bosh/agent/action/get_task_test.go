package action_test

import (
	. "bosh/agent/action"
	boshtask "bosh/agent/task"
	faketask "bosh/agent/task/fakes"
	boshassert "bosh/assert"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildGetTaskAction() (*faketask.FakeService, GetTaskAction) {
	taskService := &faketask.FakeService{}
	return taskService, NewGetTask(taskService)
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("get task should be synchronous", func() {
			_, action := buildGetTaskAction()
			assert.False(GinkgoT(), action.IsAsynchronous())
		})
		It("get task run returns a running task", func() {

			taskService, action := buildGetTaskAction()

			taskService.Tasks = map[string]boshtask.Task{
				"57": boshtask.Task{
					Id:    "found-57-id",
					State: boshtask.TaskStateRunning,
				},
			}

			taskValue, err := action.Run("57")
			assert.NoError(GinkgoT(), err)
			boshassert.MatchesJsonString(GinkgoT(), taskValue, `{"agent_task_id":"found-57-id","state":"running"}`)
		})
		It("get task run returns a failed task", func() {

			taskService, action := buildGetTaskAction()

			taskService.Tasks = map[string]boshtask.Task{
				"57": boshtask.Task{
					Id:    "found-57-id",
					State: boshtask.TaskStateFailed,
					Error: errors.New("Oops we failed..."),
				},
			}

			taskValue, err := action.Run("57")
			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), "Oops we failed...", err.Error())
			boshassert.MatchesJsonString(GinkgoT(), taskValue, `null`)
		})
		It("get task run returns a successful task", func() {

			taskService, action := buildGetTaskAction()

			taskService.Tasks = map[string]boshtask.Task{
				"57": boshtask.Task{
					Id:    "found-57-id",
					State: boshtask.TaskStateDone,
					Value: "some-task-value",
				},
			}

			taskValue, err := action.Run("57")
			assert.NoError(GinkgoT(), err)
			boshassert.MatchesJsonString(GinkgoT(), taskValue, `"some-task-value"`)
		})
		It("get task run when task is not found", func() {

			taskService, action := buildGetTaskAction()

			taskService.Tasks = map[string]boshtask.Task{}

			_, err := action.Run("57")
			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), "Task with id 57 could not be found", err.Error())
		})
	})
}
