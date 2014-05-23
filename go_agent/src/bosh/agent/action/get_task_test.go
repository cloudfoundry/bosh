package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	boshtask "bosh/agent/task"
	faketask "bosh/agent/task/fakes"
	boshassert "bosh/assert"
)

var _ = Describe("GetTask", func() {
	var (
		taskService *faketask.FakeService
		action      GetTaskAction
	)

	BeforeEach(func() {
		taskService = faketask.NewFakeService()
		action = NewGetTask(taskService)
	})

	It("is synchronous", func() {
		Expect(action.IsAsynchronous()).To(BeFalse())
	})

	It("is not persistent", func() {
		Expect(action.IsPersistent()).To(BeFalse())
	})

	It("returns a running task", func() {
		taskService.StartedTasks["fake-task-id"] = boshtask.Task{
			ID:    "fake-task-id",
			State: boshtask.TaskStateRunning,
		}

		taskValue, err := action.Run("fake-task-id")
		Expect(err).ToNot(HaveOccurred())

		// Check JSON key casing
		boshassert.MatchesJSONString(GinkgoT(), taskValue,
			`{"agent_task_id":"fake-task-id","state":"running"}`)
	})

	It("returns a failed task", func() {
		taskService.StartedTasks["fake-task-id"] = boshtask.Task{
			ID:    "fake-task-id",
			State: boshtask.TaskStateFailed,
			Error: errors.New("fake-task-error"),
		}

		taskValue, err := action.Run("fake-task-id")
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(Equal("Task fake-task-id result: fake-task-error"))
		Expect(taskValue).To(BeNil())
	})

	It("returns a successful task", func() {
		taskService.StartedTasks["fake-task-id"] = boshtask.Task{
			ID:    "fake-task-id",
			State: boshtask.TaskStateDone,
			Value: "some-task-value",
		}

		taskValue, err := action.Run("fake-task-id")
		Expect(err).ToNot(HaveOccurred())
		Expect(taskValue).To(Equal("some-task-value"))
	})

	It("returns error when task is not found", func() {
		taskService.StartedTasks = map[string]boshtask.Task{}

		_, err := action.Run("fake-task-id")
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(Equal("Task with id fake-task-id could not be found"))
	})
})
