package platform

import "bosh/settings"

type Platform interface {
	SetupSsh(publicKey, username string) (err error)
	SetupDhcp(networks settings.Networks) (err error)
}
