package net

import (
	boshsettings "bosh/settings"
)

type NetManager interface {
	// SetupManualNetworking configures network interfaces with a static ip.
	// If errChan is provided, nil or an error will be sent
	// upon completion of background network reconfiguration (e.g. arping).
	SetupManualNetworking(networks boshsettings.Networks, errChan chan error) (err error)

	SetupDhcp(networks boshsettings.Networks) (err error)
}

type customNetwork struct {
	boshsettings.Network
	Interface         string
	NetworkIP         string
	Broadcast         string
	HasDefaultGateway bool
}

type dnsConfigArg struct {
	DNSServers []string
}
