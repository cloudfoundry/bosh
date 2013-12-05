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

func New(inf boshinf.Infrastructure, platform boshplatform.Platform) (b bootstrap) {
	b.infrastructure = inf
	b.platform = platform
	b.fs = platform.GetFs()
	return
}

func (boot bootstrap) Run() (settingsProvider *boshsettings.Provider, err error) {
	err = boot.platform.SetupRuntimeConfiguration()
	if err != nil {
		err = bosherr.WrapError(err, "Setting up runtime configuration")
		return
	}

	err = boot.infrastructure.SetupSsh(boot.platform, boshsettings.VCAP_USERNAME)
	if err != nil {
		err = bosherr.WrapError(err, "Setting up ssh")
		return
	}

	settings, err := boot.fetchSettings()
	if err != nil {
		err = bosherr.WrapError(err, "Fetching settings")
		return
	}
	settingsProvider = boshsettings.NewProvider(settings)

	err = boot.setUserPasswords(settings)
	if err != nil {
		err = bosherr.WrapError(err, "Settings user password")
		return
	}

	err = boot.platform.SetupHostname(settings.AgentId)
	if err != nil {
		err = bosherr.WrapError(err, "Setting up hostname")
		return
	}

	err = boot.infrastructure.SetupNetworking(boot.platform, settings.Networks)
	if err != nil {
		err = bosherr.WrapError(err, "Setting up networking")
		return
	}

	err = boot.platform.SetTimeWithNtpServers(settings.Ntp, filepath.Join(boshsettings.VCAP_BASE_DIR, "/bosh/etc/ntpserver"))
	if err != nil {
		err = bosherr.WrapError(err, "Setting up NTP servers")
		return
	}

	err = boot.platform.SetupEphemeralDiskWithPath(settings.Disks.Ephemeral, filepath.Join(boshsettings.VCAP_BASE_DIR, "data"))
	if err != nil {
		err = bosherr.WrapError(err, "Setting up ephemeral disk")
		return
	}

	monitUserFilePath := filepath.Join(boshsettings.VCAP_BASE_DIR, "monit", "monit.user")
	if !boot.fs.FileExists(monitUserFilePath) {
		_, err = boot.fs.WriteToFile(monitUserFilePath, "vcap:random-password")
		if err != nil {
			err = bosherr.WrapError(err, "Writing monit user file")
			return
		}
	}

	err = boot.platform.StartMonit()
	if err != nil {
		err = bosherr.WrapError(err, "Starting monit")
		return
	}
	return
}

func (boot bootstrap) fetchSettings() (settings boshsettings.Settings, err error) {
	settingsPath := filepath.Join(boshsettings.VCAP_BASE_DIR, "bosh", "settings.json")

	existingSettingsJson, readError := boot.platform.GetFs().ReadFile(settingsPath)
	if readError == nil {
		err = json.Unmarshal([]byte(existingSettingsJson), &settings)
		return
	}

	settings, err = boot.infrastructure.GetSettings()
	if err != nil {
		err = bosherr.WrapError(err, "Fetching settings from infrastructure")
		return
	}

	settingsJson, err := json.Marshal(settings)
	if err != nil {
		err = bosherr.WrapError(err, "Marshalling settings json")
		return
	}

	boot.fs.WriteToFile(settingsPath, string(settingsJson))
	return
}

func (boot bootstrap) setUserPasswords(settings boshsettings.Settings) (err error) {
	password := settings.Env.GetPassword()
	if password == "" {
		return
	}

	err = boot.platform.SetUserPassword(boshsettings.ROOT_USERNAME, settings.Env.GetPassword())
	if err != nil {
		err = bosherr.WrapError(err, "Setting root password")
		return
	}

	err = boot.platform.SetUserPassword(boshsettings.VCAP_USERNAME, settings.Env.GetPassword())
	if err != nil {
		err = bosherr.WrapError(err, "Setting vcap password")
	}
	return
}
