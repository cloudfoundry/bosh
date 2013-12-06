package action

import (
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesettings "bosh/settings/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestUnmountDiskWhenTheDiskIsMounted(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	platform.UnmountPersistentDiskDidUnmount = true

	unmountDisk := buildUnmountDiskAction(platform)
	payload := `{"arguments":["vol-123"]}`

	result, err := unmountDisk.Run([]byte(payload))
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, result, `{"message":"Unmounted partition of /dev/sdf"}`)

	assert.Equal(t, platform.UnmountPersistentDiskDevicePath, "/dev/sdf")
}

func TestUnmountDiskWhenTheDiskIsNotMounted(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	platform.UnmountPersistentDiskDidUnmount = false

	mountDisk := buildUnmountDiskAction(platform)
	payload := `{"arguments":["vol-123"]}`

	result, err := mountDisk.Run([]byte(payload))
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, result, `{"message":"Partition of /dev/sdf is not mounted"}`)

	assert.Equal(t, platform.UnmountPersistentDiskDevicePath, "/dev/sdf")
}

func TestUnmountDiskWithMissingVolumeId(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	unmountDisk := buildUnmountDiskAction(platform)

	payload := `{"arguments":[]}`

	_, err := unmountDisk.Run([]byte(payload))
	assert.Error(t, err)
}

func TestUnmountDiskWhenDevicePathNotFound(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	mountDisk := buildUnmountDiskAction(platform)

	payload := `{"arguments":["vol-456"]}`

	_, err := mountDisk.Run([]byte(payload))
	assert.Error(t, err)
}

func buildUnmountDiskAction(platform *fakeplatform.FakePlatform) (unmountDisk Action) {
	settings := &fakesettings.FakeSettingsService{
		Disks: boshsettings.Disks{
			Persistent: map[string]string{"vol-123": "/dev/sdf"},
		},
	}
	return newUnmountDisk(settings, platform)
}
