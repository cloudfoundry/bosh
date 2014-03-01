package infrastructure

import (
	bosherr "bosh/errors"
	boshdevicepathresolver "bosh/infrastructure/device_path_resolver"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"encoding/json"
	"time"
)

type vsphereInfrastructure struct {
	platform           boshplatform.Platform
	diskWaitTimeout    time.Duration
	devicePathResolver boshdevicepathresolver.DevicePathResolver
}

func NewVsphereInfrastructure(platform boshplatform.Platform, devicePathResolver boshdevicepathresolver.DevicePathResolver) (inf vsphereInfrastructure) {
	inf.platform = platform

	inf.devicePathResolver = devicePathResolver
	inf.platform.SetDevicePathResolver(inf.devicePathResolver)

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

func (inf vsphereInfrastructure) MountPersistentDisk(volumeId string, mountPoint string) (err error) {
	return
}
