package action

import (
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestMountDisk(t *testing.T) {
	settings := boshsettings.Settings{}
	settings.Disks.Persistent = map[string]string{"vol-123": "/dev/sdf"}
	platform, mountDisk := buildMountDiskAction(settings)

	payload := `{"arguments":["vol-123"]}`
	result, err := mountDisk.Run([]byte(payload))
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, result, "{}")

	assert.Equal(t, platform.MountPersistentDiskDevicePath, "/dev/sdf")
	assert.Equal(t, platform.MountPersistentDiskMountPoint, "/var/vcap/store")
}

func TestMountDiskWithMissingVolumeId(t *testing.T) {
	settings := boshsettings.Settings{}
	_, mountDisk := buildMountDiskAction(settings)

	payload := `{"arguments":[]}`
	_, err := mountDisk.Run([]byte(payload))
	assert.Error(t, err)
}

func TestMountDiskWhenDevicePathNotFound(t *testing.T) {
	settings := boshsettings.Settings{}
	settings.Disks.Persistent = map[string]string{"vol-123": "/dev/sdf"}
	_, mountDisk := buildMountDiskAction(settings)

	payload := `{"arguments":["vol-456"]}`
	_, err := mountDisk.Run([]byte(payload))
	assert.Error(t, err)
}

func buildMountDiskAction(settings boshsettings.Settings) (*fakeplatform.FakePlatform, mountDiskAction) {
	platform := fakeplatform.NewFakePlatform()
	action := newMountDisk(settings, platform)
	return platform, action
}
