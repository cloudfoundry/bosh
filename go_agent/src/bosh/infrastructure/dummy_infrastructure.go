package infrastructure

import boshsettings "bosh/settings"

type dummyInfrastructure struct {
}

func newDummyInfrastructure() (inf dummyInfrastructure) {
	return
}

func (inf dummyInfrastructure) SetupSsh(delegate SshSetupDelegate, username string) (err error) {
	return
}

func (inf dummyInfrastructure) GetSettings() (settings boshsettings.Settings, err error) {
	settings.Mbus = "nats://foo:bar@127.0.0.1:4222"
	return
}

func (inf dummyInfrastructure) SetupNetworking(delegate NetworkingDelegate, networks boshsettings.Networks) (err error) {
	return
}
