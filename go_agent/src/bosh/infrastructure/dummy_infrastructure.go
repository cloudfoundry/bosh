package infrastructure

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
	"encoding/json"
	"path/filepath"
)

type dummyInfrastructure struct {
	fs          boshsys.FileSystem
	dirProvider boshdir.DirectoriesProvider
	platform    boshplatform.Platform
}

func NewDummyInfrastructure(fs boshsys.FileSystem, dirProvider boshdir.DirectoriesProvider, platform boshplatform.Platform) (inf dummyInfrastructure) {
	inf.fs = fs
	inf.dirProvider = dirProvider
	inf.platform = platform
	return
}

func (inf dummyInfrastructure) SetupSsh(username string) (err error) {
	return
}

func (inf dummyInfrastructure) GetSettings() (settings boshsettings.Settings, err error) {
	settingsPath := filepath.Join(inf.dirProvider.BaseDir(), "bosh", "settings.json")
	contents, err := inf.fs.ReadFile(settingsPath)
	if err != nil {
		err = bosherr.WrapError(err, "Read settings file")
		return
	}

	err = json.Unmarshal([]byte(contents), &settings)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshal json settings")
		return
	}

	return
}

func (inf dummyInfrastructure) SetupNetworking(networks boshsettings.Networks) (err error) {
	return
}

func (inf dummyInfrastructure) GetEphemeralDiskPath(devicePath string) (realPath string, found bool) {
	return inf.platform.NormalizeDiskPath(devicePath)
}
