package fakes

import (
	boshsettings "bosh/settings"
)

type FakeDefaultNetworkResolver struct {
	GetDefaultNetworkNetwork boshsettings.Network
	GetDefaultNetworkErr     error
}

func (r *FakeDefaultNetworkResolver) GetDefaultNetwork() (boshsettings.Network, error) {
	return r.GetDefaultNetworkNetwork, r.GetDefaultNetworkErr
}
