package infrastructure

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"encoding/json"
)

type vsphereInfrastructure struct {
	platform boshplatform.Platform
}

func NewVsphereInfrastructure(platform boshplatform.Platform) (inf vsphereInfrastructure) {
	inf.platform = platform
	return
}

func (inf vsphereInfrastructure) SetupSsh(username string) (err error) {
	return
}

func (inf vsphereInfrastructure) GetSettings() (settings boshsettings.Settings, err error) {
	contents, err := inf.platform.GetFileContentsFromCDROM("env")
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

func (inf vsphereInfrastructure) SetupNetworking(networks boshsettings.Networks) (err error) {
	return inf.platform.SetupManualNetworking(networks)
}

func (inf vsphereInfrastructure) GetEphemeralDiskPath(devicePath string) (realPath string, found bool) {
	return inf.platform.NormalizeDiskPath("/dev/sdb")
}
