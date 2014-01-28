package infrastructure

import (
	bosherr "bosh/errors"
	boshsettings "bosh/settings"
	"encoding/json"
)

type vsphereInfrastructure struct {
	cdromDelegate CDROMDelegate
}

func newVsphereInfrastructure(delegate CDROMDelegate) (inf vsphereInfrastructure) {
	inf.cdromDelegate = delegate
	return
}

func (inf vsphereInfrastructure) SetupSsh(delegate SshSetupDelegate, username string) (err error) {
	return
}

func (inf vsphereInfrastructure) GetSettings() (settings boshsettings.Settings, err error) {
	contents, err := inf.cdromDelegate.GetFileContentsFromCDROM("env")
	if err != nil {
		err = bosherr.WrapError(err, "Reading contents from CDROM")
		return
	}

	err = json.Unmarshal(contents, &settings)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling settings from CDROM")
	}

	return
}

func (inf vsphereInfrastructure) SetupNetworking(delegate NetworkingDelegate, networks boshsettings.Networks) (err error) {
	return
}
