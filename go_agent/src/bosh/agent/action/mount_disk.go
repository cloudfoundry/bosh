package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
)

type mountDiskAction struct {
	settings    boshsettings.Service
	platform    boshplatform.Platform
	dirProvider boshdirs.DirectoriesProvider
}

func newMountDisk(settings boshsettings.Service, platform boshplatform.Platform, dirProvider boshdirs.DirectoriesProvider) (mountDisk mountDiskAction) {
	mountDisk.settings = settings
	mountDisk.platform = platform
	mountDisk.dirProvider = dirProvider
	return
}

func (a mountDiskAction) IsAsynchronous() bool {
	return true
}

func (a mountDiskAction) Run(volumeId string) (value interface{}, err error) {
	err = a.settings.Refresh()
	if err != nil {
		err = bosherr.WrapError(err, "Refreshing the settings")
		return
	}

	disksSettings := a.settings.GetDisks()
	devicePath, found := disksSettings.Persistent[volumeId]
	if !found {
		err = bosherr.New("Persistent disk with volume id '%s' could not be found", volumeId)
		return
	}

	mountPoint := a.dirProvider.StoreDir()

	isMountPoint, err := a.platform.IsMountPoint(mountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Checking mount point")
		return
	}
	if isMountPoint {
		mountPoint = a.dirProvider.StoreMigrationDir()
	}

	err = a.platform.MountPersistentDisk(devicePath, mountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Mounting persistent disk")
		return
	}

	value = make(map[string]string)
	return
}
