package infrastructure_test

import (
	. "bosh/infrastructure"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		var (
			vsphere  Infrastructure
			platform *fakeplatform.FakePlatform
		)

		BeforeEach(func() {
			platform = fakeplatform.NewFakePlatform()
		})

		JustBeforeEach(func() {
			vsphere = NewVsphereInfrastructure(platform)
		})

		It("vsphere get settings", func() {
			platform.GetFileContentsFromCDROMContents = []byte(`{"agent_id": "123"}`)

			settings, err := vsphere.GetSettings()
			Expect(err).NotTo(HaveOccurred())

			Expect(platform.GetFileContentsFromCDROMPath).To(Equal("env"))
			Expect(settings.AgentId).To(Equal("123"))
		})

		It("vsphere setup networking", func() {
			networks := boshsettings.Networks{"bosh": boshsettings.Network{}}

			vsphere.SetupNetworking(networks)

			Expect(platform.SetupManualNetworkingNetworks).To(Equal(networks))
		})

		It("vsphere get ephemeral disk path", func() {
			platform.NormalizeDiskPathRealPath = "/dev/sdb"
			platform.NormalizeDiskPathFound = true

			realPath, found := vsphere.GetEphemeralDiskPath("does not matter")
			Expect(found).To(Equal(true))

			Expect(realPath).To(Equal("/dev/sdb"))
			Expect(platform.NormalizeDiskPathPath).To(Equal("/dev/sdb"))
		})
	})
}
