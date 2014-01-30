package infrastructure

import (
	boshsettings "bosh/settings"
	boshsys "bosh/system"
)

type Infrastructure interface {
	SetupSsh(delegate SshSetupDelegate, username string) (err error)
	GetSettings() (settings boshsettings.Settings, err error)
	SetupNetworking(delegate NetworkingDelegate, networks boshsettings.Networks) (err error)
	GetEphemeralDiskPath(devicePath string, fs boshsys.FileSystem) (realPath string, found bool)
	GetPersistentDiskPath(devicePath string, fs boshsys.FileSystem, scsiDelegate ScsiDelegate) (realPath string, found bool)
}
