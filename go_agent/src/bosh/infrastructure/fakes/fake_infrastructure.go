package fakes

import (
	boshsettings "bosh/settings"
)

type FakeInfrastructure struct {
	Settings                boshsettings.Settings
	SetupSshUsername        string
	SetupNetworkingNetworks boshsettings.Networks
}

func (i *FakeInfrastructure) SetupSsh(username string) (err error) {
	i.SetupSshUsername = username
	return
}

func (i *FakeInfrastructure) GetSettings() (settings boshsettings.Settings, err error) {
	settings = i.Settings
	return
}

func (i *FakeInfrastructure) SetupNetworking(networks boshsettings.Networks) (err error) {
	i.SetupNetworkingNetworks = networks
	return
}
