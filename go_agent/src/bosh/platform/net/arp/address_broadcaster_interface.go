package arp

import (
	boship "bosh/platform/net/ip"
)

type AddressBroadcaster interface {
	BroadcastMACAddresses([]boship.InterfaceAddress)
}
