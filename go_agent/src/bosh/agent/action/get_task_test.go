package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	. "bosh/agent/action"
	boshtask "bosh/agent/task"
	faketask "bosh/agent/task/fakes"
	boshassert "bosh/assert"
)

func init() {
	Describe("GetTask", func() {
		var (
			taskService *faketask.FakeService
			action      GetTaskAction
		)

		BeforeEach(func() {
			taskService = &faketask.FakeService{}
			action = NewGetTask(taskService)
		})

		It("is synchronous", func() {
			Expect(action.IsAsynchronous()).To(BeFalse())
		})

		It("is not persistent", func() {
			Expect(action.IsPersistent()).To(BeFalse())
		})

		It("returns a running task", func() {
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

		It("returns a failed task", func() {
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

		It("returns a successful task", func() {
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

		It("returns error when task is not found", func() {
			taskService.Tasks = map[string]boshtask.Task{}

			_, err := action.Run("57")
			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), "Task with id 57 could not be found", err.Error())
		})
	})
}
