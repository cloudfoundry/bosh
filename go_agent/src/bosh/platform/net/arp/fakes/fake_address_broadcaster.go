package fakes

import (
	boship "bosh/platform/net/ip"
)

type FakeAddressBroadcaster struct {
	BroadcastMACAddressesAddresses []boship.InterfaceAddress
}

func (b *FakeAddressBroadcaster) BroadcastMACAddresses(addresses []boship.InterfaceAddress) {
	b.BroadcastMACAddressesAddresses = addresses
}
