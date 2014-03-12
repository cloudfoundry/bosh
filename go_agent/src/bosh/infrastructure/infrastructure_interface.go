package infrastructure

import (
	boshdevicepathresolver "bosh/infrastructure/device_path_resolver"
	boshsettings "bosh/settings"
)

type Infrastructure interface {
	SetupSsh(username string) (err error)
	GetSettings() (settings boshsettings.Settings, err error)
	SetupNetworking(networks boshsettings.Networks) (err error)
	GetEphemeralDiskPath(devicePath string) (realPath string, found bool)
	GetDevicePathResolver() (devicePathResolver boshdevicepathresolver.DevicePathResolver)
	MountPersistentDisk(volumeId string, mountPoint string) error
}
