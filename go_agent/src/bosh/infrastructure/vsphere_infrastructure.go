package infrastructure

import (
	boshsettings "bosh/settings"
)

type vsphereInfrastructure struct {
}

func newVsphereInfrastructure() (infrastructure vsphereInfrastructure) {
	return
}

func (inf vsphereInfrastructure) SetupSsh(delegate SshSetupDelegate, username string) (err error) {
	return
}

func (inf vsphereInfrastructure) GetSettings() (settings boshsettings.Settings, err error) {
	return
}

func (inf vsphereInfrastructure) SetupNetworking(delegate NetworkingDelegate, networks boshsettings.Networks) (err error) {
	return
}
