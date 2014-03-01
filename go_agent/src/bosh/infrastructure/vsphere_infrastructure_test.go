package infrastructure_test

import (
	. "bosh/infrastructure"
	boshdevicepathresolver "bosh/infrastructure/device_path_resolver"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"time"
)

func init() {
	Describe("vSphere Infrastructure", func() {
		var (
			vsphere                Infrastructure
			platform               *fakeplatform.FakePlatform
			fakeDevicePathResolver *boshdevicepathresolver.FakeDevicePathResolver
		)

		BeforeEach(func() {
			platform = fakeplatform.NewFakePlatform()
			fakeDevicePathResolver = boshdevicepathresolver.NewFakeDevicePathResolver(1*time.Millisecond, platform.GetFs())
		})

		JustBeforeEach(func() {
			vsphere = NewVsphereInfrastructure(platform, fakeDevicePathResolver)
		})

		Describe("GetSettings", func() {
			It("vsphere get settings", func() {
				platform.GetFileContentsFromCDROMContents = []byte(`{"agent_id": "123"}`)

				settings, err := vsphere.GetSettings()
				Expect(err).NotTo(HaveOccurred())

				Expect(platform.GetFileContentsFromCDROMPath).To(Equal("env"))
				Expect(settings.AgentId).To(Equal("123"))
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
				platform.NormalizeDiskPathRealPath = "/dev/sdb"
				platform.NormalizeDiskPathFound = true

				realPath, found := vsphere.GetEphemeralDiskPath("does not matter")
				Expect(found).To(Equal(true))

				Expect(realPath).To(Equal("/dev/sdb"))
				Expect(platform.NormalizeDiskPathPath).To(Equal("/dev/sdb"))
			})
		})
		PDescribe("MountPersistentDisk", func() {
		})
	})
}
