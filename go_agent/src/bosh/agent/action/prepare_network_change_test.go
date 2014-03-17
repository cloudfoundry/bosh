package action_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	fakeplatform "bosh/platform/fakes"
	boshsys "bosh/system"
)

func buildPrepareNetworkChangeAction() (PrepareNetworkChangeAction, boshsys.FileSystem) {
	platform := fakeplatform.NewFakePlatform()
	return NewPrepareNetworkChange(platform), platform.GetFs()
}

func init() {
	Describe("prepareNetworkChange", func() {
		It("is synchronous", func() {
			action, _ := buildPrepareNetworkChangeAction()
			Expect(action.IsAsynchronous()).To(BeFalse())
		})

		It("removes the network rules file", func() {
			action, fs := buildPrepareNetworkChangeAction()
			fs.WriteFile("/etc/udev/rules.d/70-persistent-net.rules", []byte{})

			resp, err := action.Run()
			Expect(err).NotTo(HaveOccurred())
			Expect(resp).To(Equal("ok"))
			Expect(fs.FileExists("/etc/udev/rules.d/70-persistent-net.rules")).To(BeFalse())
		})
	})
}
