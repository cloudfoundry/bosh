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

func (a mountDiskAction) IsAsynchronous() bool {
	return true
}

func (a mountDiskAction) Run(payloadBytes []byte) (value interface{}, err error) {
	err = a.settings.Refresh()
	if err != nil {
		err = bosherr.WrapError(err, "Refreshing the settings")
		return
	}

	diskParams, err := NewDiskParams(a.settings, payloadBytes)
	if err != nil {
		err = bosherr.WrapError(err, "Parsing payload into disk params")
		return
	}

	devicePath, err := diskParams.GetDevicePath()
	if err != nil {
		err = bosherr.WrapError(err, "Getting device path from params")
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
