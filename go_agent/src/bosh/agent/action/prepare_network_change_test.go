package action_test

import (
	. "bosh/agent/action"
	fakeplatform "bosh/platform/fakes"
	boshsys "bosh/system"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildPrepareAction() (action PrepareNetworkChangeAction, fs boshsys.FileSystem) {
	platform := fakeplatform.NewFakePlatform()
	fs = platform.GetFs()
	action = NewPrepareNetworkChange(platform)

	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("prepare network change should be synchronous", func() {
			action, _ := buildPrepareAction()
			assert.False(GinkgoT(), action.IsAsynchronous())
		})
		It("prepare network change", func() {

			action, fs := buildPrepareAction()
			fs.WriteToFile("/etc/udev/rules.d/70-persistent-net.rules", "")

			resp, err := action.Run()

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "ok", resp)
			assert.False(GinkgoT(), fs.FileExists("/etc/udev/rules.d/70-persistent-net.rules"))
		})
	})
}
