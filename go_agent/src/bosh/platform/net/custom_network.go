package net

import (
	bosharp "bosh/platform/net/arp"
	boshsettings "bosh/settings"
)

type dnsConfigArg struct {
	DNSServers []string
}

type customNetwork struct {
	boshsettings.Network
	Interface         string
	NetworkIP         string
	Broadcast         string
	HasDefaultGateway bool
}

func (c customNetwork) ToInterfaceAddress() bosharp.InterfaceAddress {
	return bosharp.InterfaceAddress{Interface: c.Interface, IP: c.IP}
}

// toInterfaceAddresses bulk converts customNetworks to InterfaceAddresses
func toInterfaceAddresses(networks []customNetwork) (addresses []bosharp.InterfaceAddress) {
	for _, network := range networks {
		addresses = append(addresses, network.ToInterfaceAddress())
	}
	return
}
