package infrastructure

import (
	"encoding/json"
	"time"

	bosherr "bosh/errors"
	boshdpresolv "bosh/infrastructure/devicepathresolver"
	boshlog "bosh/logger"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type vsphereInfrastructure struct {
	logger             boshlog.Logger
	platform           boshplatform.Platform
	diskWaitTimeout    time.Duration
	devicePathResolver boshdpresolv.DevicePathResolver
}

func NewVsphereInfrastructure(
	platform boshplatform.Platform,
	devicePathResolver boshdpresolv.DevicePathResolver,
	logger boshlog.Logger,
) (inf vsphereInfrastructure) {
	inf.platform = platform
	inf.logger = logger
	inf.devicePathResolver = devicePathResolver
	return
}

func (inf vsphereInfrastructure) GetDevicePathResolver() boshdpresolv.DevicePathResolver {
	return inf.devicePathResolver
}

func (inf vsphereInfrastructure) SetupSsh(username string) error {
	return nil
}

func (inf vsphereInfrastructure) GetSettings() (boshsettings.Settings, error) {
	var settings boshsettings.Settings

	contents, err := inf.platform.GetFileContentsFromCDROM("env")
	if err != nil {
		return settings, bosherr.WrapError(err, "Reading contents from CDROM")
	}

	inf.logger.Debug("disks", "Got CDrom data %v", string(contents))

	err = json.Unmarshal(contents, &settings)
	if err != nil {
		return settings, bosherr.WrapError(err, "Unmarshalling settings from CDROM")
	}

	inf.logger.Debug("disks", "Number of persistent disks %v", len(settings.Disks.Persistent))

	return settings, nil
}

func (inf vsphereInfrastructure) SetupNetworking(networks boshsettings.Networks) error {
	return inf.platform.SetupManualNetworking(networks)
}

func (inf vsphereInfrastructure) GetEphemeralDiskPath(string) (string, bool) {
	return "/dev/sdb", true
}
