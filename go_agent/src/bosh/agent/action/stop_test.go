package action_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	fakejobsuper "bosh/jobsupervisor/fakes"
)

func init() {
	Describe("Stop", func() {
		var (
			jobSupervisor *fakejobsuper.FakeJobSupervisor
			action        StopAction
		)

		BeforeEach(func() {
			jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
			action = NewStop(jobSupervisor)
		})

		It("is asynchronous", func() {
			Expect(action.IsAsynchronous()).To(BeTrue())
		})

		It("is not persistent", func() {
			Expect(action.IsPersistent()).To(BeFalse())
		})

		It("returns stopped", func() {
			stopped, err := action.Run()
			Expect(err).ToNot(HaveOccurred())
			Expect(stopped).To(Equal("stopped"))
		})

		It("stops job supervisor services", func() {
			_, err := action.Run()
			Expect(err).ToNot(HaveOccurred())
			Expect(jobSupervisor.Stopped).To(BeTrue())
		})
	})
}
