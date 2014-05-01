package task_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/task"
)

var _ = Describe("Task", func() {
	var (
		task Task
	)

	BeforeEach(func() {
		task = Task{}
	})

	Describe("Cancel", func() {
		It("runs cancel function", func() {
			cancelCalled := false
			task.CancelFunc = func(_ Task) error { cancelCalled = true; return nil }

			err := task.Cancel()
			Expect(err).ToNot(HaveOccurred())
			Expect(cancelCalled).To(BeTrue())
		})

		It("returns error returned by cancel function", func() {
			task.CancelFunc = func(_ Task) error { return errors.New("fake-cancel-err") }

			err := task.Cancel()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-cancel-err"))
		})

		It("returns no error when cancel function is not set", func() {
			err := task.Cancel()
			Expect(err).ToNot(HaveOccurred())
		})
	})
})
