package testhelpers

import (
	"bosh/settings"
)

type FakePlatform struct {
}

func (p *FakePlatform) SetupSsh(publicKey, username string) (err error) {
	return
}

func (p *FakePlatform) SetupDhcp(networks settings.Networks) (err error) {
	return
}
