package infrastructure

import (
	infrastructure "bosh/infrastructure"
)

type FakeInfrastructure struct {
	PublicKey string
	Settings  infrastructure.Settings
}

func (i *FakeInfrastructure) GetPublicKey() (publicKey string, err error) {
	publicKey = i.PublicKey
	return
}

func (i *FakeInfrastructure) GetSettings() (settings infrastructure.Settings, err error) {
	settings = i.Settings
	return
}
