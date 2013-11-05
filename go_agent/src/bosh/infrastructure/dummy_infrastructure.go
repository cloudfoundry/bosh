package infrastructure

import "bosh/settings"

type dummyInfrastructure struct {
}

func newDummyInfrastructure() (inf dummyInfrastructure) {
	return
}

func (inf dummyInfrastructure) SetupSsh(delegate SshSetupDelegate, username string) (err error) {
	return
}

func (inf dummyInfrastructure) GetSettings() (s settings.Settings, err error) {
	s.Mbus = "nats://foo:bar@127.0.0.1:4222"
	return
}

func (inf dummyInfrastructure) SetupNetworking(delegate NetworkingDelegate, networks settings.Networks) (err error) {
	return
}
