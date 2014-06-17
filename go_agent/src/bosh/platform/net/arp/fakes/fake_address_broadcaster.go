package fakes

import (
	bosharp "bosh/platform/net/arp"
)

type FakeAddressBroadcaster struct {
	BroadcastMACAddressesAddresses []bosharp.InterfaceAddress
}

func (b *FakeAddressBroadcaster) BroadcastMACAddresses(addresses []bosharp.InterfaceAddress) {
	b.BroadcastMACAddressesAddresses = addresses
}
