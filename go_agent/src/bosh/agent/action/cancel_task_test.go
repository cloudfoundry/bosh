package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	boshtask "bosh/agent/task"
	faketask "bosh/agent/task/fakes"
)

var _ = Describe("CancelTaskAction", func() {
	var (
		taskService *faketask.FakeService
		action      CancelTaskAction
	)

	BeforeEach(func() {
		taskService = faketask.NewFakeService()
		action = NewCancelTask(taskService)
	})

	It("is synchronous", func() {
		Expect(action.IsAsynchronous()).To(BeFalse())
	})

	It("is not persistent", func() {
		Expect(action.IsPersistent()).To(BeFalse())
	})

	It("cancels task if task is found", func() {
		cancelCalled := false
		cancelFunc := func(_ boshtask.Task) error { cancelCalled = true; return nil }

		taskService.StartedTasks["fake-task-id"] = boshtask.Task{
			ID:         "fake-task-id",
			State:      boshtask.TaskStateRunning,
			CancelFunc: cancelFunc,
		}

		value, err := action.Run("fake-task-id")
		Expect(err).ToNot(HaveOccurred())
		Expect(value).To(Equal("canceled")) // 1 l

		Expect(cancelCalled).To(BeTrue())
	})

	It("returns error when canceling task fails", func() {
		cancelFunc := func(_ boshtask.Task) error { return errors.New("fake-cancel-err") }

		taskService.StartedTasks["fake-task-id"] = boshtask.Task{
			ID:         "fake-task-id",
			State:      boshtask.TaskStateRunning,
			CancelFunc: cancelFunc,
		}

		_, err := action.Run("fake-task-id")
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(ContainSubstring("fake-cancel-err"))
	})

	It("returns error when task is not found", func() {
		taskService.StartedTasks = map[string]boshtask.Task{}

		_, err := action.Run("fake-task-id")
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(Equal("Task with id fake-task-id could not be found"))
	})
})
