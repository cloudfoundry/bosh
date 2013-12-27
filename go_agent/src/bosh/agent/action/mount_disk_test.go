package action

import (
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshdirs "bosh/settings/directories"
	fakesettings "bosh/settings/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestMountDiskShouldBeAsynchronous(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	_, action := buildMountDiskAction(settings)
	assert.True(t, action.IsAsynchronous())
}

func TestMountDisk(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	settings.Disks.Persistent = map[string]string{"vol-123": "/dev/sdf"}
	platform, mountDisk := buildMountDiskAction(settings)

	result, err := mountDisk.Run("vol-123")
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, result, "{}")

	assert.True(t, settings.SettingsWereRefreshed)

	assert.Equal(t, platform.MountPersistentDiskDevicePath, "/dev/sdf")
	assert.Equal(t, platform.MountPersistentDiskMountPoint, "/foo/store")
}

func TestMountDiskWhenStoreAlreadyMounted(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	settings.Disks.Persistent = map[string]string{"vol-123": "/dev/sdf"}
	platform, mountDisk := buildMountDiskAction(settings)

	platform.IsMountPointResult = true

	result, err := mountDisk.Run("vol-123")
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, result, "{}")

	assert.Equal(t, platform.IsMountPointPath, "/foo/store")

	assert.Equal(t, platform.MountPersistentDiskDevicePath, "/dev/sdf")
	assert.Equal(t, platform.MountPersistentDiskMountPoint, "/foo/store_migration_target")
}

func TestMountDiskWhenDevicePathNotFound(t *testing.T) {
	settings := &fakesettings.FakeSettingsService{}
	settings.Disks.Persistent = map[string]string{"vol-123": "/dev/sdf"}
	_, mountDisk := buildMountDiskAction(settings)

	_, err := mountDisk.Run("vol-456")
	assert.Error(t, err)
}

func buildMountDiskAction(settings *fakesettings.FakeSettingsService) (*fakeplatform.FakePlatform, mountDiskAction) {
	platform := fakeplatform.NewFakePlatform()
	action := newMountDisk(settings, platform, boshdirs.NewDirectoriesProvider("/foo"))
	return platform, action
}
