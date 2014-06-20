package fakes

import (
	boshsettings "bosh/settings"
)

type FakeNetManager struct {
	FakeDefaultNetworkResolver

	SetupManualNetworkingNetworks boshsettings.Networks
	SetupManualNetworkingErr      error

	SetupDhcpNetworks boshsettings.Networks
	SetupDhcpErr      error
}

func (net *FakeNetManager) SetupManualNetworking(networks boshsettings.Networks, errCh chan error) error {
	net.SetupManualNetworkingNetworks = networks
	return net.SetupManualNetworkingErr
}

func (net *FakeNetManager) SetupDhcp(networks boshsettings.Networks, errCh chan error) error {
	net.SetupDhcpNetworks = networks
	return net.SetupDhcpErr
}
