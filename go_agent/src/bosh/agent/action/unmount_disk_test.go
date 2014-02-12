package action_test

import (
	. "bosh/agent/action"
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesettings "bosh/settings/fakes"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildUnmountDiskAction(platform *fakeplatform.FakePlatform) (unmountDisk UnmountDiskAction) {
	settings := &fakesettings.FakeSettingsService{
		Disks: boshsettings.Disks{
			Persistent: map[string]string{"vol-123": "/dev/sdf"},
		},
	}
	return NewUnmountDisk(settings, platform)
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("unmount disk should be asynchronous", func() {
			platform := fakeplatform.NewFakePlatform()
			action := buildUnmountDiskAction(platform)
			assert.True(GinkgoT(), action.IsAsynchronous())
		})
		It("unmount disk when the disk is mounted", func() {

			platform := fakeplatform.NewFakePlatform()
			platform.UnmountPersistentDiskDidUnmount = true

			unmountDisk := buildUnmountDiskAction(platform)

			result, err := unmountDisk.Run("vol-123")
			assert.NoError(GinkgoT(), err)
			boshassert.MatchesJsonString(GinkgoT(), result, `{"message":"Unmounted partition of /dev/sdf"}`)

			assert.Equal(GinkgoT(), platform.UnmountPersistentDiskDevicePath, "/dev/sdf")
		})
		It("unmount disk when the disk is not mounted", func() {

			platform := fakeplatform.NewFakePlatform()
			platform.UnmountPersistentDiskDidUnmount = false

			mountDisk := buildUnmountDiskAction(platform)

			result, err := mountDisk.Run("vol-123")
			assert.NoError(GinkgoT(), err)
			boshassert.MatchesJsonString(GinkgoT(), result, `{"message":"Partition of /dev/sdf is not mounted"}`)

			assert.Equal(GinkgoT(), platform.UnmountPersistentDiskDevicePath, "/dev/sdf")
		})
		It("unmount disk when device path not found", func() {

			platform := fakeplatform.NewFakePlatform()
			mountDisk := buildUnmountDiskAction(platform)

			_, err := mountDisk.Run("vol-456")
			assert.Error(GinkgoT(), err)
		})
	})
}
