package platform

import "bosh/settings"

type dummyPlatform struct {
}

func newDummyPlatform() (p dummyPlatform) {
	return
}

func (p dummyPlatform) SetupSsh(publicKey, username string) (err error) {
	return
}

func (p dummyPlatform) SetupDhcp(networks settings.Networks) (err error) {
	return
}
