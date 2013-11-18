package fakes

import (
	boshinf "bosh/infrastructure"
	boshsettings "bosh/settings"
)

type FakeInfrastructure struct {
	Settings                boshsettings.Settings
	SetupSshDelegate        boshinf.SshSetupDelegate
	SetupSshUsername        string
	SetupNetworkingDelegate boshinf.NetworkingDelegate
	SetupNetworkingNetworks boshsettings.Networks
}

func (i *FakeInfrastructure) SetupSsh(delegate boshinf.SshSetupDelegate, username string) (err error) {
	i.SetupSshDelegate = delegate
	i.SetupSshUsername = username
	return
}

func (i *FakeInfrastructure) GetSettings() (settings boshsettings.Settings, err error) {
	settings = i.Settings
	return
}

func (i *FakeInfrastructure) SetupNetworking(delegate boshinf.NetworkingDelegate, networks boshsettings.Networks) (err error) {
	i.SetupNetworkingDelegate = delegate
	i.SetupNetworkingNetworks = networks
	return
}
