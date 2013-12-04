package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"fmt"
)

type unmountDiskAction struct {
	settings boshsettings.Settings
	platform boshplatform.Platform
}

func newUnmountDisk(settings boshsettings.Settings, platform boshplatform.Platform) (unmountDisk unmountDiskAction) {
	unmountDisk.settings = settings
	unmountDisk.platform = platform
	return
}

func (a unmountDiskAction) Run(payloadBytes []byte) (value interface{}, err error) {
	diskParams, err := NewDiskParams(a.settings, payloadBytes)
	if err != nil {
		return
	}

	devicePath, err := diskParams.GetDevicePath()
	if err != nil {
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
