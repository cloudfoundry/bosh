package bootstrap

import (
	bosherr "bosh/errors"
	boshinf "bosh/infrastructure"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"encoding/json"
	"path/filepath"
)

const (
	VCAP_USERNAME = "vcap"
	VCAP_BASE_DIR = "/var/vcap"
)

type bootstrap struct {
	fs             boshsys.FileSystem
	infrastructure boshinf.Infrastructure
	platform       boshplatform.Platform
}

func New(fs boshsys.FileSystem, inf boshinf.Infrastructure, platform boshplatform.Platform) (b bootstrap) {
	b.fs = fs
	b.infrastructure = inf
	b.platform = platform
	return
}

func (boot bootstrap) Run() (settings boshsettings.Settings, err error) {
	err = boot.infrastructure.SetupSsh(boot.platform, VCAP_USERNAME)
	if err != nil {
		return
	}

	settings, err = boot.fetchSettings()
	if err != nil {
		return
	}

	err = boot.infrastructure.SetupNetworking(boot.platform, settings.Networks)
	if err != nil {
		return
	}

	err = boot.platform.SetupEphemeralDiskWithPath(settings.Disks.Ephemeral, filepath.Join(VCAP_BASE_DIR, "data"))
	if err != nil {
		return
	}

	err = boot.fs.Symlink(filepath.Join(VCAP_BASE_DIR, "data", "sys"), filepath.Join(VCAP_BASE_DIR, "sys"))
	return
}

func (boot bootstrap) fetchSettings() (settings boshsettings.Settings, err error) {
	settings, err = boot.infrastructure.GetSettings()
	if err != nil {
		err = bosherr.WrapError(err, "Error fetching settings")
		return
	}

	settingsJson, err := json.Marshal(settings)
	if err != nil {
		err = bosherr.WrapError(err, "Error marshalling settings json")
		return
	}

	boot.fs.WriteToFile(filepath.Join(VCAP_BASE_DIR, "bosh", "settings.json"), string(settingsJson))
	return
}
