package action

import (
	"errors"
	"fmt"

	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type UnmountDiskAction struct {
	settingsService boshsettings.Service
	platform        boshplatform.Platform
}

func NewUnmountDisk(
	settingsService boshsettings.Service,
	platform boshplatform.Platform,
) (unmountDisk UnmountDiskAction) {
	unmountDisk.settingsService = settingsService
	unmountDisk.platform = platform
	return
}

func (a UnmountDiskAction) IsAsynchronous() bool {
	return true
}

func (a UnmountDiskAction) IsPersistent() bool {
	return false
}

func (a UnmountDiskAction) Run(volumeID string) (value interface{}, err error) {
	settings := a.settingsService.GetSettings()

	devicePath, found := settings.Disks.Persistent[volumeID]
	if !found {
		err = bosherr.New("Persistent disk with volume id '%s' could not be found", volumeID)
		return
	}

	didUnmount, err := a.platform.UnmountPersistentDisk(devicePath)
	if err != nil {
		err = bosherr.WrapError(err, "Unmounting persistent disk")
		return
	}

	msg := fmt.Sprintf("Partition of %s is not mounted", devicePath)

	if didUnmount {
		msg = fmt.Sprintf("Unmounted partition of %s", devicePath)
	}

	type valueType struct {
		Message string `json:"message"`
	}

	value = valueType{Message: msg}
	return
}

func (a UnmountDiskAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a UnmountDiskAction) Cancel() error {
	return errors.New("not supported")
}
