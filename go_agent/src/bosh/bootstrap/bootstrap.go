package bootstrap

import (
	"errors"

	bosherr "bosh/errors"
	boshinf "bosh/infrastructure"
	boshlog "bosh/logger"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
)

type bootstrap struct {
	fs                      boshsys.FileSystem
	infrastructure          boshinf.Infrastructure
	platform                boshplatform.Platform
	dirProvider             boshdir.DirectoriesProvider
	settingsServiceProvider boshsettings.ServiceProvider
	logger                  boshlog.Logger
}

func New(
	inf boshinf.Infrastructure,
	platform boshplatform.Platform,
	dirProvider boshdir.DirectoriesProvider,
	settingsServiceProvider boshsettings.ServiceProvider,
	logger boshlog.Logger,
) (b bootstrap) {
	b.fs = platform.GetFs()
	b.infrastructure = inf
	b.platform = platform
	b.dirProvider = dirProvider
	b.settingsServiceProvider = settingsServiceProvider
	b.logger = logger
	return
}

func (boot bootstrap) Run() (settingsService boshsettings.Service, err error) {
	err = boot.platform.SetupRuntimeConfiguration()
	if err != nil {
		err = bosherr.WrapError(err, "Setting up runtime configuration")
		return
	}

	err = boot.infrastructure.SetupSsh(boshsettings.VCAPUsername)
	if err != nil {
		err = bosherr.WrapError(err, "Setting up ssh")
		return
	}

	settingsService = boot.settingsServiceProvider.NewService(
		boot.fs,
		boot.dirProvider.BoshDir(),
		boot.infrastructure.GetSettings,
		boot.platform,
		boot.logger,
	)

	err = settingsService.LoadSettings()
	if err != nil {
		err = bosherr.WrapError(err, "Fetching settings")
		return
	}

	settings := settingsService.GetSettings()

	err = boot.setUserPasswords(settings.Env)
	if err != nil {
		err = bosherr.WrapError(err, "Settings user password")
		return
	}

	err = boot.platform.SetupHostname(settings.AgentID)
	if err != nil {
		err = bosherr.WrapError(err, "Setting up hostname")
		return
	}

	err = boot.infrastructure.SetupNetworking(settings.Networks)
	if err != nil {
		err = bosherr.WrapError(err, "Setting up networking")
		return
	}

	err = boot.platform.SetTimeWithNtpServers(settings.Ntp)
	if err != nil {
		err = bosherr.WrapError(err, "Setting up NTP servers")
		return
	}

	ephemeralDiskPath, found := boot.infrastructure.GetEphemeralDiskPath(settings.Disks.Ephemeral)
	if !found {
		err = bosherr.New("Could not find ephemeral disk '%s'", settings.Disks.Ephemeral)
		return
	}

	err = boot.platform.SetupEphemeralDiskWithPath(ephemeralDiskPath)
	if err != nil {
		err = bosherr.WrapError(err, "Setting up ephemeral disk")
		return
	}

	err = boot.platform.SetupDataDir()
	if err != nil {
		err = bosherr.WrapError(err, "Setting up data dir")
		return
	}

	err = boot.platform.SetupTmpDir()
	if err != nil {
		err = bosherr.WrapError(err, "Setting up tmp dir")
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

func (boot bootstrap) setUserPasswords(env boshsettings.Env) error {
	password := env.GetPassword()
	if password == "" {
		return nil
	}

	err := boot.platform.SetUserPassword(boshsettings.RootUsername, password)
	if err != nil {
		return bosherr.WrapError(err, "Setting root password")
	}

	err = boot.platform.SetUserPassword(boshsettings.VCAPUsername, password)
	if err != nil {
		return bosherr.WrapError(err, "Setting vcap password")
	}

	return nil
}
