package infrastructure_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/infrastructure"
	fakedpresolv "bosh/infrastructure/devicepathresolver/fakes"
	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
)

var _ = Describe("vSphere Infrastructure", func() {
	var (
		logger             boshlog.Logger
		vsphere            Infrastructure
		platform           *fakeplatform.FakePlatform
		devicePathResolver *fakedpresolv.FakeDevicePathResolver
	)

	BeforeEach(func() {
		platform = fakeplatform.NewFakePlatform()
		devicePathResolver = fakedpresolv.NewFakeDevicePathResolver()
		logger = boshlog.NewLogger(boshlog.LevelNone)
	})

	JustBeforeEach(func() {
		vsphere = NewVsphereInfrastructure(platform, devicePathResolver, logger)
	})

	Describe("GetSettings", func() {
		It("vsphere get settings", func() {
			platform.GetFileContentsFromCDROMContents = []byte(`{"agent_id": "123"}`)

			settings, err := vsphere.GetSettings()
			Expect(err).NotTo(HaveOccurred())

			Expect(platform.GetFileContentsFromCDROMPath).To(Equal("env"))
			Expect(settings.AgentID).To(Equal("123"))
		})
	})

	Describe("SetupNetworking", func() {
		It("vsphere setup networking", func() {
			networks := boshsettings.Networks{"bosh": boshsettings.Network{}}

			vsphere.SetupNetworking(networks)

			Expect(platform.SetupManualNetworkingNetworks).To(Equal(networks))
		})
	})

	Describe("GetEphemeralDiskPath", func() {
		It("vsphere get ephemeral disk path", func() {
			realPath, found := vsphere.GetEphemeralDiskPath("does not matter")
			Expect(found).To(Equal(true))

			Expect(realPath).To(Equal("/dev/sdb"))
		})
	})
})
