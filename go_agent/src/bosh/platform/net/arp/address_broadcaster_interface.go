package arp

type InterfaceAddress struct {
	// the interface name
	Interface string

	// the exposed internet protocol address of the above interface
	IP string
}

type AddressBroadcaster interface {
	BroadcastMACAddresses([]InterfaceAddress)
}
