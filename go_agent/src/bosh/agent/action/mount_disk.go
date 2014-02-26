package action

import (
	bosherr "bosh/errors"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
)

type diskMounter interface {
	MountPersistentDisk(volumeId string, mountPoint string) error
}

type mountPoints interface {
	IsMountPoint(string) (bool, error)
}

type MountDiskAction struct {
	settings    boshsettings.Service
	platform    diskMounter
	mountPoints mountPoints
	dirProvider boshdirs.DirectoriesProvider
}

func NewMountDisk(settings boshsettings.Service, platform diskMounter, mountPoints mountPoints, dirProvider boshdirs.DirectoriesProvider) (mountDisk MountDiskAction) {
	mountDisk.settings = settings
	mountDisk.platform = platform
	mountDisk.mountPoints = mountPoints
	mountDisk.dirProvider = dirProvider
	return
}

func (a MountDiskAction) IsAsynchronous() bool {
	return true
}

func (a MountDiskAction) Run(disk_cid string) (value interface{}, err error) {
	err = a.settings.Refresh()
	if err != nil {
		err = bosherr.WrapError(err, "Refreshing the settings")
		return
	}

	disksSettings := a.settings.GetDisks()
	devicePath, found := disksSettings.Persistent[disk_cid]
	if !found {
		err = bosherr.New("Persistent disk with volume id '%s' could not be found", disk_cid)
		return
	}

	mountPoint := a.dirProvider.StoreDir()

	isMountPoint, err := a.mountPoints.IsMountPoint(mountPoint)
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
