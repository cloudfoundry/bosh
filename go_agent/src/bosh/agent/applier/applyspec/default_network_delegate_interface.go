package applyspec

import (
	boshsettings "bosh/settings"
)

type DefaultNetworkDelegate interface {
	GetDefaultNetwork() (boshsettings.Network, error)
}
