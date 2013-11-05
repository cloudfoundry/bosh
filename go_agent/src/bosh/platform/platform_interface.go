package platform

import "bosh/settings"

type Platform interface {
	SetupDhcp(networks settings.Networks) (err error)
}
