package infrastructure

import "bosh/settings"

type Infrastructure interface {
	SetupSsh(delegate SshSetupDelegate, username string) (err error)
	GetSettings() (settings settings.Settings, err error)
	SetupNetworking(delegate NetworkingDelegate, networks settings.Networks) (err error)
}
