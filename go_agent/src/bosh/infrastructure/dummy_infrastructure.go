package infrastructure

import (
	bosherr "bosh/errors"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
	"encoding/json"
	"path/filepath"
)

type dummyInfrastructure struct {
	fs          boshsys.FileSystem
	dirProvider boshdir.DirectoriesProvider
}

func newDummyInfrastructure(fs boshsys.FileSystem, dirProvider boshdir.DirectoriesProvider) (inf dummyInfrastructure) {
	inf.fs = fs
	inf.dirProvider = dirProvider
	return
}

func (inf dummyInfrastructure) SetupSsh(delegate SshSetupDelegate, username string) (err error) {
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

func (inf dummyInfrastructure) SetupNetworking(delegate NetworkingDelegate, networks boshsettings.Networks) (err error) {
	return
}
