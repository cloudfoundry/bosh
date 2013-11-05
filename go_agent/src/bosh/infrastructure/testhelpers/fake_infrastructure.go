package testhelpers

import (
	"bosh/infrastructure"
	"bosh/settings"
)

type FakeInfrastructure struct {
	Settings                settings.Settings
	SetupSshDelegate        infrastructure.SshSetupDelegate
	SetupSshUsername        string
	SetupNetworkingDelegate infrastructure.NetworkingDelegate
	SetupNetworkingNetworks settings.Networks
}

func (i *FakeInfrastructure) SetupSsh(delegate infrastructure.SshSetupDelegate, username string) (err error) {
	i.SetupSshDelegate = delegate
	i.SetupSshUsername = username
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
