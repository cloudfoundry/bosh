package bootstrap

import (
	bosherr "bosh/errors"
	boshinf "bosh/infrastructure"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
	"encoding/json"
	"errors"
	"path/filepath"
)

type bootstrap struct {
	fs             boshsys.FileSystem
	infrastructure boshinf.Infrastructure
	platform       boshplatform.Platform
	dirProvider    boshdir.DirectoriesProvider
}

func New(inf boshinf.Infrastructure, platform boshplatform.Platform, dirProvider boshdir.DirectoriesProvider) (b bootstrap) {
	b.infrastructure = inf
	b.platform = platform
	b.dirProvider = dirProvider
	b.fs = platform.GetFs()
	return
}

func (boot bootstrap) Run() (settingsService boshsettings.Service, err error) {
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

	settings, err := boot.fetchInitialSettings()
	if err != nil {
		err = bosherr.WrapError(err, "Fetching settings")
		return
	}
	settingsService = boshsettings.NewService(settings, boot.infrastructure.GetSettings)

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

	err = boot.platform.SetTimeWithNtpServers(settings.Ntp)
	if err != nil {
		err = bosherr.WrapError(err, "Setting up NTP servers")
		return
	}

	err = boot.platform.SetupEphemeralDiskWithPath(settings.Disks.Ephemeral)
	if err != nil {
		err = bosherr.WrapError(err, "Setting up ephemeral disk")
		return
	}

	if len(settings.Disks.Persistent) > 1 {
		err = errors.New("Error mounting persistent disk, there is more than one persistent disk")
		return
	}

	for _, devicePath := range settings.Disks.Persistent {
		err = boot.platform.MountPersistentDisk(devicePath, boot.dirProvider.StoreDir())
		if err != nil {
			err = bosherr.WrapError(err, "Mounting persistent disk")
			return
		}
	}

	err = boot.platform.SetupMonitUser()
	if err != nil {
		err = bosherr.WrapError(err, "Setting up monit user")
		return
	}

	err = boot.platform.StartMonit()
	if err != nil {
		err = bosherr.WrapError(err, "Starting monit")
		return
	}
	return
}

func (boot bootstrap) fetchInitialSettings() (settings boshsettings.Settings, err error) {
	settingsPath := filepath.Join(boot.dirProvider.BaseDir(), "bosh", "settings.json")

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
