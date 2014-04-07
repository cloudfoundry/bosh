package infrastructure

import (
	boshdpresolv "bosh/infrastructure/device_path_resolver"
	boshsettings "bosh/settings"
)

type Infrastructure interface {
	SetupSsh(username string) (err error)
	GetSettings() (settings boshsettings.Settings, err error)
	SetupNetworking(networks boshsettings.Networks) (err error)
	GetEphemeralDiskPath(devicePath string) (realPath string, found bool)
	GetDevicePathResolver() (devicePathResolver boshdpresolv.DevicePathResolver)
	MountPersistentDisk(volumeID string, mountPoint string) error
}
