package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"fmt"
)

type unmountDiskAction struct {
	settings boshsettings.Service
	platform boshplatform.Platform
}

func newUnmountDisk(settings boshsettings.Service, platform boshplatform.Platform) (unmountDisk unmountDiskAction) {
	unmountDisk.settings = settings
	unmountDisk.platform = platform
	return
}

func (a unmountDiskAction) IsAsynchronous() bool {
	return true
}

func (a unmountDiskAction) Run(volumeId string) (value interface{}, err error) {
	disksSettings := a.settings.GetDisks()
	devicePath, found := disksSettings.Persistent[volumeId]
	if !found {
		err = bosherr.New("Persistent disk with volume id '%s' could not be found", volumeId)
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
