package infrastructure

import "bosh/settings"

type NetworkingDelegate interface {
	SetupDhcp(networks settings.Networks) (err error)
}
