package action

import (
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesettings "bosh/settings/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestUnmountDiskShouldBeAsynchronous(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	action := buildUnmountDiskAction(platform)
	assert.True(t, action.IsAsynchronous())
}

func TestUnmountDiskWhenTheDiskIsMounted(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	platform.UnmountPersistentDiskDidUnmount = true

	unmountDisk := buildUnmountDiskAction(platform)

	result, err := unmountDisk.Run("vol-123")
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, result, `{"message":"Unmounted partition of /dev/sdf"}`)

	assert.Equal(t, platform.UnmountPersistentDiskDevicePath, "/dev/sdf")
}

func TestUnmountDiskWhenTheDiskIsNotMounted(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	platform.UnmountPersistentDiskDidUnmount = false

	mountDisk := buildUnmountDiskAction(platform)

	result, err := mountDisk.Run("vol-123")
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, result, `{"message":"Partition of /dev/sdf is not mounted"}`)

	assert.Equal(t, platform.UnmountPersistentDiskDevicePath, "/dev/sdf")
}

func TestUnmountDiskWhenDevicePathNotFound(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	mountDisk := buildUnmountDiskAction(platform)

	_, err := mountDisk.Run("vol-456")
	assert.Error(t, err)
}

func buildUnmountDiskAction(platform *fakeplatform.FakePlatform) (unmountDisk unmountDiskAction) {
	settings := &fakesettings.FakeSettingsService{
		Disks: boshsettings.Disks{
			Persistent: map[string]string{"vol-123": "/dev/sdf"},
		},
	}
	return newUnmountDisk(settings, platform)
}
