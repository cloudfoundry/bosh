package action_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	fakejobsuper "bosh/jobsupervisor/fakes"
)

func init() {
	Describe("Start", func() {
		var (
			jobSupervisor *fakejobsuper.FakeJobSupervisor
			action        StartAction
		)

		BeforeEach(func() {
			jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
			action = NewStart(jobSupervisor)
		})

		It("is synchronous", func() {
			Expect(action.IsAsynchronous()).To(BeFalse())
		})

		It("is not persistent", func() {
			Expect(action.IsPersistent()).To(BeFalse())
		})

		It("returns started", func() {
			started, err := action.Run()
			Expect(err).ToNot(HaveOccurred())
			Expect(started).To(Equal("started"))
		})

		It("starts monitor services", func() {
			_, err := action.Run()
			Expect(err).ToNot(HaveOccurred())
			Expect(jobSupervisor.Started).To(BeTrue())
		})
	})
}
