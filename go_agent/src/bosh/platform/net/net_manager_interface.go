package net

import (
	boshsettings "bosh/settings"
)

type NetManager interface {
	SetupManualNetworking(networks boshsettings.Networks) (err error)
	SetupDhcp(networks boshsettings.Networks) (err error)
}

type CustomNetwork struct {
	boshsettings.Network
	Interface         string
	NetworkIp         string
	Broadcast         string
	HasDefaultGateway bool
}

type dnsConfigArg struct {
	DnsServers []string
}
