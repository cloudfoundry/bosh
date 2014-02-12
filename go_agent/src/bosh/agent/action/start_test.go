package action_test

import (
	. "bosh/agent/action"
	fakejobsuper "bosh/jobsupervisor/fakes"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildStartAction() (jobSupervisor *fakejobsuper.FakeJobSupervisor, action StartAction) {
	jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
	action = NewStart(jobSupervisor)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("start should be synchronous", func() {
			_, action := buildStartAction()
			assert.False(GinkgoT(), action.IsAsynchronous())
		})
		It("start run returns started", func() {

			_, action := buildStartAction()

			started, err := action.Run()
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "started", started)
		})
		It("start run starts monitor services", func() {

			jobSupervisor, action := buildStartAction()

			_, err := action.Run()
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), jobSupervisor.Started)
		})
	})
}
