package action

import (
	"errors"

	bosherr "bosh/errors"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
)

type diskMounter interface {
	MountPersistentDisk(volumeID, mountPoint string) error
}

type mountPoints interface {
	IsMountPoint(string) (bool, error)
}

type MountDiskAction struct {
	settings    boshsettings.Service
	diskMounter diskMounter
	mountPoints mountPoints
	dirProvider boshdirs.DirectoriesProvider
}

func NewMountDisk(
	settings boshsettings.Service,
	diskMounter diskMounter,
	mountPoints mountPoints,
	dirProvider boshdirs.DirectoriesProvider,
) (mountDisk MountDiskAction) {
	mountDisk.settings = settings
	mountDisk.diskMounter = diskMounter
	mountDisk.mountPoints = mountPoints
	mountDisk.dirProvider = dirProvider
	return
}

func (a MountDiskAction) IsAsynchronous() bool {
	return true
}

func (a MountDiskAction) IsPersistent() bool {
	return false
}

func (a MountDiskAction) Run(diskCid string) (interface{}, error) {
	err := a.settings.LoadSettings()
	if err != nil {
		return nil, bosherr.WrapError(err, "Refreshing the settings")
	}

	devicePath, found := a.settings.GetDisks().Persistent[diskCid]
	if !found {
		return nil, bosherr.New("Persistent disk with volume id '%s' could not be found", diskCid)
	}

	mountPoint := a.dirProvider.StoreDir()

	isMountPoint, err := a.mountPoints.IsMountPoint(mountPoint)
	if err != nil {
		return nil, bosherr.WrapError(err, "Checking mount point")
	}
	if isMountPoint {
		mountPoint = a.dirProvider.StoreMigrationDir()
	}

	err = a.diskMounter.MountPersistentDisk(devicePath, mountPoint)
	if err != nil {
		return nil, bosherr.WrapError(err, "Mounting persistent disk")
	}

	return map[string]string{}, nil
}

func (a MountDiskAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a MountDiskAction) Cancel() error {
	return errors.New("not supported")
}
