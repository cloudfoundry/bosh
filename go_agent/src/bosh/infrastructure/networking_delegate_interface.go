package infrastructure

import boshsettings "bosh/settings"

type NetworkingDelegate interface {
	SetupDhcp(networks boshsettings.Networks) (err error)
	SetupManualNetworking(networks boshsettings.Networks) (err error)
}
