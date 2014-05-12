package fakes

import (
	boshsettings "bosh/settings"
)

type FakeNetManager struct {
	FakeDefaultNetworkResolver

	SetupManualNetworkingNetworks boshsettings.Networks
	SetupManualNetworkingErrCh    chan error
	SetupManualNetworkingErr      error

	SetupDhcpNetworks boshsettings.Networks
	SetupDhcpErr      error
}

func (net *FakeNetManager) SetupManualNetworking(networks boshsettings.Networks, errCh chan error) error {
	net.SetupManualNetworkingNetworks = networks
	net.SetupManualNetworkingErrCh = errCh
	return net.SetupManualNetworkingErr
}

func (net *FakeNetManager) SetupDhcp(networks boshsettings.Networks) error {
	net.SetupDhcpNetworks = networks
	return net.SetupDhcpErr
}
