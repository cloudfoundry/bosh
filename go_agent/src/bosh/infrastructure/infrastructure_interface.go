package infrastructure

import boshsettings "bosh/settings"

type Infrastructure interface {
	SetupSsh(username string) (err error)
	GetSettings() (settings boshsettings.Settings, err error)
	SetupNetworking(networks boshsettings.Networks) (err error)
	GetEphemeralDiskPath(devicePath string) (realPath string, found bool)
}
