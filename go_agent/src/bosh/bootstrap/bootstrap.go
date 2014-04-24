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
		boot.logger,
	)

	err = settingsService.LoadSettings()
	if err != nil {
		err = bosherr.WrapError(err, "Fetching settings")
		return
	}

	settings := settingsService.GetSettings()

	err = boot.setUserPasswords(settings)
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

	disks := settingsService.GetDisks()

	ephemeralDiskPath, found := boot.infrastructure.GetEphemeralDiskPath(disks.Ephemeral)
	if !found {
		err = bosherr.New("Could not find ephemeral disk '%s'", disks.Ephemeral)
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

	if len(disks.Persistent) > 1 {
		err = errors.New("Error mounting persistent disk, there is more than one persistent disk")
		return
	}

	for _, devicePath := range disks.Persistent {
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

func (boot bootstrap) setUserPasswords(settings boshsettings.Settings) (err error) {
	password := settings.Env.GetPassword()
	if password == "" {
		return
	}

	err = boot.platform.SetUserPassword(boshsettings.RootUsername, settings.Env.GetPassword())
	if err != nil {
		err = bosherr.WrapError(err, "Setting root password")
		return
	}

	err = boot.platform.SetUserPassword(boshsettings.VCAPUsername, settings.Env.GetPassword())
	if err != nil {
		err = bosherr.WrapError(err, "Setting vcap password")
	}
	return
}
