package infrastructure_test

import (
	"os"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/infrastructure"
	fakedpresolv "bosh/infrastructure/devicepathresolver/fakes"
	boshlog "bosh/logger"
	boshdisk "bosh/platform/disk"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
)

func init() {
	Describe("vSphere Infrastructure", func() {
		var (
			logger                 boshlog.Logger
			vsphere                Infrastructure
			platform               *fakeplatform.FakePlatform
			fakeDevicePathResolver *fakedpresolv.FakeDevicePathResolver
		)

		BeforeEach(func() {
			platform = fakeplatform.NewFakePlatform()
			fakeDevicePathResolver = fakedpresolv.NewFakeDevicePathResolver(1*time.Millisecond, platform.GetFs())
			logger = boshlog.NewLogger(boshlog.LevelNone)
		})

		JustBeforeEach(func() {
			vsphere = NewVsphereInfrastructure(platform, fakeDevicePathResolver, logger)
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

		Describe("MountPersistentDisk", func() {
			BeforeEach(func() {
				fakeDevicePathResolver.RealDevicePath = "fake-real-device-path"
			})

			It("creates the mount directory with the correct permissions", func() {
				vsphere.MountPersistentDisk("fake-volume-id", "/mnt/point")

				mountPoint := platform.Fs.GetFileTestStat("/mnt/point")
				Expect(mountPoint.FileType).To(Equal(fakesys.FakeFileTypeDir))
				Expect(mountPoint.FileMode).To(Equal(os.FileMode(0700)))
			})

			It("partitions the disk", func() {
				vsphere.MountPersistentDisk("fake-volume-id", "/mnt/point")

				Expect(platform.FakeDiskManager.FakePartitioner.PartitionDevicePath).To(Equal("fake-real-device-path"))
				partitions := []boshdisk.Partition{
					{Type: boshdisk.PartitionTypeLinux},
				}
				Expect(platform.FakeDiskManager.FakePartitioner.PartitionPartitions).To(Equal(partitions))
			})

			It("formats the disk", func() {
				vsphere.MountPersistentDisk("fake-volume-id", "/mnt/point")

				Expect(platform.FakeDiskManager.FakeFormatter.FormatPartitionPaths).To(Equal([]string{"fake-real-device-path1"}))
				Expect(platform.FakeDiskManager.FakeFormatter.FormatFsTypes).To(Equal([]boshdisk.FileSystemType{boshdisk.FileSystemExt4}))
			})

			It("mounts the disk", func() {
				vsphere.MountPersistentDisk("fake-volume-id", "/mnt/point")

				Expect(platform.FakeDiskManager.FakeMounter.MountPartitionPaths).To(Equal([]string{"fake-real-device-path1"}))
				Expect(platform.FakeDiskManager.FakeMounter.MountMountPoints).To(Equal([]string{"/mnt/point"}))
			})
		})
	})
}
