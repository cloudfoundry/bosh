package action_test

import (
	. "bosh/agent/action"
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshdirs "bosh/settings/directories"
	fakesettings "bosh/settings/fakes"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func buildMountDiskAction(settings *fakesettings.FakeSettingsService) (*fakeplatform.FakePlatform, MountDiskAction) {
	platform := fakeplatform.NewFakePlatform()
	action := NewMountDisk(settings, platform, boshdirs.NewDirectoriesProvider("/foo"))
	return platform, action
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("mount disk should be asynchronous", func() {
			settings := &fakesettings.FakeSettingsService{}
			_, action := buildMountDiskAction(settings)
			Expect(action.IsAsynchronous()).To(BeTrue())
		})

		It("mount disk", func() {
			settings := &fakesettings.FakeSettingsService{}
			settings.Disks.Persistent = map[string]string{"vol-123": "/dev/sdf"}
			platform, mountDisk := buildMountDiskAction(settings)

			result, err := mountDisk.Run("vol-123")
			Expect(err).NotTo(HaveOccurred())
			boshassert.MatchesJsonString(GinkgoT(), result, "{}")

			Expect(settings.SettingsWereRefreshed).To(BeTrue())

			Expect(platform.MountPersistentDiskDevicePath).To(Equal("/dev/sdf"))
			Expect(platform.MountPersistentDiskMountPoint).To(Equal("/foo/store"))
		})

		It("mount disk when store already mounted", func() {
			settings := &fakesettings.FakeSettingsService{}
			settings.Disks.Persistent = map[string]string{"vol-123": "/dev/sdf"}
			platform, mountDisk := buildMountDiskAction(settings)

			platform.IsMountPointResult = true

			result, err := mountDisk.Run("vol-123")
			Expect(err).NotTo(HaveOccurred())
			boshassert.MatchesJsonString(GinkgoT(), result, "{}")

			Expect(platform.IsMountPointPath).To(Equal("/foo/store"))

			Expect(platform.MountPersistentDiskDevicePath).To(Equal("/dev/sdf"))
			Expect(platform.MountPersistentDiskMountPoint).To(Equal("/foo/store_migration_target"))
		})

		It("mount disk when device path not found", func() {
			settings := &fakesettings.FakeSettingsService{}
			settings.Disks.Persistent = map[string]string{"vol-123": "/dev/sdf"}
			_, mountDisk := buildMountDiskAction(settings)

			_, err := mountDisk.Run("vol-456")
			Expect(err).To(HaveOccurred())
		})
	})
}
