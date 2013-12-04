package action

import (
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestMountDisk(t *testing.T) {
	platform, mountDisk := createMountDisk()

	payload := `{"arguments":["vol-123"]}`

	result, err := mountDisk.Run([]byte(payload))
	assert.NoError(t, err)
	boshassert.MatchesJsonString(t, result, "{}")

	assert.Equal(t, platform.MountPersistentDiskDevicePath, "/dev/sdf")
	assert.Equal(t, platform.MountPersistentDiskMountPoint, "/var/vcap/store")
}

func TestMountDiskWithMissingVolumeId(t *testing.T) {
	_, mountDisk := createMountDisk()

	payload := `{"arguments":[]}`

	_, err := mountDisk.Run([]byte(payload))
	assert.Error(t, err)
}

func TestMountDiskWhenDevicePathNotFound(t *testing.T) {
	_, mountDisk := createMountDisk()

	payload := `{"arguments":["vol-456"]}`

	_, err := mountDisk.Run([]byte(payload))
	assert.Error(t, err)
}

func createMountDisk() (platform *fakeplatform.FakePlatform, mountDisk Action) {
	settings, platform, blobstore, taskService := getFakeFactoryDependencies()
	settings.Disks.Persistent = map[string]string{"vol-123": "/dev/sdf"}

	factory := NewFactory(settings, platform, blobstore, taskService)
	mountDisk = factory.Create("mount_disk")
	return
}
