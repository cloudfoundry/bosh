package testhelpers

import (
	"bosh/infrastructure"
	"bosh/settings"
)

type FakePlatform struct {
	SetupNetworkingNetworkingDelegate infrastructure.NetworkingDelegate
}

func (p *FakePlatform) SetupDhcp(networks settings.Networks) (err error) {
	return
}
