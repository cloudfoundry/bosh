package fakes

import (
	gonet "net"
)

type FakeIPResolver struct {
	GetPrimaryIPv4InterfaceName string
	GetPrimaryIPv4IPNet         *gonet.IPNet
	GetPrimaryIPv4Err           error
}

func (r *FakeIPResolver) GetPrimaryIPv4(interfaceName string) (*gonet.IPNet, error) {
	r.GetPrimaryIPv4InterfaceName = interfaceName
	return r.GetPrimaryIPv4IPNet, r.GetPrimaryIPv4Err
}
