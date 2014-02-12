package action_test

import (
	. "bosh/agent/action"
	fakejobsuper "bosh/jobsupervisor/fakes"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildStopAction() (jobSupervisor *fakejobsuper.FakeJobSupervisor, action StopAction) {
	jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
	action = NewStop(jobSupervisor)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("stop should be asynchronous", func() {
			_, action := buildStopAction()
			assert.True(GinkgoT(), action.IsAsynchronous())
		})
		It("stop run returns stopped", func() {

			_, action := buildStopAction()
			stopped, err := action.Run()
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "stopped", stopped)
		})
		It("stop run stops job supervisor services", func() {

			jobSupervisor, action := buildStopAction()

			_, err := action.Run()
			assert.NoError(GinkgoT(), err)

			assert.True(GinkgoT(), jobSupervisor.Stopped)
		})
	})
}
