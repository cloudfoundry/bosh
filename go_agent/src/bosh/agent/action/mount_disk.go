package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type mountDiskAction struct {
	settings boshsettings.Service
	platform boshplatform.Platform
}

func newMountDisk(settings boshsettings.Service, platform boshplatform.Platform) (mountDisk mountDiskAction) {
	mountDisk.settings = settings
	mountDisk.platform = platform
	return
}

func (a mountDiskAction) Run(payloadBytes []byte) (value interface{}, err error) {
	diskParams, err := NewDiskParams(a.settings, payloadBytes)
	if err != nil {
		return
	}

	devicePath, err := diskParams.GetDevicePath()
	if err != nil {
		return
	}

	mountPoint := a.settings.GetStoreMountPoint()

	isMountPoint, err := a.platform.IsMountPoint(mountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Checking mount point")
		return
	}
	if isMountPoint {
		mountPoint = a.settings.GetStoreMigrationMountPoint()
	}

	err = a.platform.MountPersistentDisk(devicePath, mountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Mounting persistent disk")
		return
	}

	value = make(map[string]string)
	return
}
