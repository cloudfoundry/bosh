package infrastructure

import boshsettings "bosh/settings"

type Infrastructure interface {
	SetupSsh(delegate SshSetupDelegate, username string) (err error)
	GetSettings() (settings boshsettings.Settings, err error)
	SetupNetworking(delegate NetworkingDelegate, networks boshsettings.Networks) (err error)
}
