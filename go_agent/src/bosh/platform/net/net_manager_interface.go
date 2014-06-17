package net

import (
	boshsettings "bosh/settings"
)

type DefaultNetworkResolver interface {
	// Ideally we would find a network based on a MAC address
	// but current CPI implementations do not include it
	GetDefaultNetwork() (boshsettings.Network, error)
}

type NetManager interface {
	// SetupManualNetworking configures network interfaces with a static ip.
	// If errCh is provided, nil or an error will be sent
	// upon completion of background network reconfiguration (e.g. arping).
	SetupManualNetworking(networks boshsettings.Networks, errCh chan error) error

	// SetupDhcp configures network interfaces using DHCP.
	// If errCh is provided, nil or an error will be sent
	// upon completion of background network reconfiguration (e.g. arping).
	SetupDhcp(networks boshsettings.Networks, errCh chan error) error

	DefaultNetworkResolver
}
