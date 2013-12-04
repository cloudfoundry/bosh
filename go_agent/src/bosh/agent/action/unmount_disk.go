package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"encoding/json"
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
	type payloadType struct {
		Arguments []string
	}

	payload := payloadType{}
	err = json.Unmarshal(payloadBytes, &payload)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling payload")
		return
	}

	if len(payload.Arguments) != 1 {
		err = bosherr.New("Invalid payload missing volume id.")
		return
	}

	volumeId := payload.Arguments[0]
	devicePath, found := a.settings.Disks.Persistent[volumeId]
	if !found {
		err = bosherr.New("Invalid payload volume id does not match")
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
