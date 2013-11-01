package infrastructure

import (
	infrastructure "bosh/infrastructure"
	"bosh/settings"
)

type FakeInfrastructure struct {
	PublicKey               string
	Settings                settings.Settings
	SetupNetworkingDelegate infrastructure.NetworkingDelegate
	SetupNetworkingNetworks settings.Networks
}

func (i *FakeInfrastructure) GetPublicKey() (publicKey string, err error) {
	publicKey = i.PublicKey
	return
}

func (i *FakeInfrastructure) GetSettings() (settings settings.Settings, err error) {
	settings = i.Settings
	return
}

func (i *FakeInfrastructure) SetupNetworking(delegate infrastructure.NetworkingDelegate, networks settings.Networks) (err error) {
	i.SetupNetworkingDelegate = delegate
	i.SetupNetworkingNetworks = networks
	return
}
