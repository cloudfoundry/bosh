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
	err = boot.platform.SetupRuntimeConfiguration()
	if err != nil {
		return
	}

	err = boot.infrastructure.SetupSsh(boot.platform, boshsettings.VCAP_USERNAME)
	if err != nil {
		return
	}

	settings, err = boot.fetchSettings()
	if err != nil {
		return
	}

	err = boot.setUserPasswords(settings)
	if err != nil {
		return
	}

	err = boot.platform.SetupHostname(settings.AgentId)
	if err != nil {
		return
	}

	err = boot.infrastructure.SetupNetworking(boot.platform, settings.Networks)
	if err != nil {
		return
	}

	err = boot.platform.SetTimeWithNtpServers(settings.Ntp, filepath.Join(boshsettings.VCAP_BASE_DIR, "/bosh/etc/ntpserver"))
	if err != nil {
		return
	}

	err = boot.platform.SetupEphemeralDiskWithPath(settings.Disks.Ephemeral, filepath.Join(boshsettings.VCAP_BASE_DIR, "data"))
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

	boot.fs.WriteToFile(filepath.Join(boshsettings.VCAP_BASE_DIR, "bosh", "settings.json"), string(settingsJson))
	return
}

func (boot bootstrap) setUserPasswords(settings boshsettings.Settings) (err error) {
	password := settings.Env.GetPassword()
	if password == "" {
		return
	}

	err = boot.platform.SetUserPassword(boshsettings.ROOT_USERNAME, settings.Env.GetPassword())
	if err != nil {
		return
	}

	err = boot.platform.SetUserPassword(boshsettings.VCAP_USERNAME, settings.Env.GetPassword())
	return
}
