package infrastructure

import (
	bosherr "bosh/errors"
	boshdevicepathresolver "bosh/infrastructure/device_path_resolver"
	boshplatform "bosh/platform"
	boshdisk "bosh/platform/disk"
	boshsettings "bosh/settings"
	"encoding/json"
	"os"
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
	inf.platform.GetFs().MkdirAll(mountPoint, os.FileMode(0700))

	realPath, err := inf.devicePathResolver.GetRealDevicePath(volumeId)

	if err != nil {
		err = bosherr.WrapError(err, "Getting real device path")
		return
	}

	partitions := []boshdisk.Partition{
		{Type: boshdisk.PartitionTypeLinux},
	}

	err = inf.platform.GetDiskManager().GetPartitioner().Partition(realPath, partitions)

	if err != nil {
		err = bosherr.WrapError(err, "Partitioning disk")
		return
	}

	partitionPath := realPath + "1"
	err = inf.platform.GetDiskManager().GetFormatter().Format(partitionPath, boshdisk.FileSystemExt4)
	if err != nil {
		err = bosherr.WrapError(err, "Formatting partition with ext4")
		return
	}

	err = inf.platform.GetDiskManager().GetMounter().Mount(partitionPath, mountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Mounting partition")
		return
	}
	return
}
