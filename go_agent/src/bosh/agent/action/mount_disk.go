package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"encoding/json"
	"path/filepath"
)

type mountDiskAction struct {
	settings boshsettings.Settings
	platform boshplatform.Platform
}

func newMountDisk(settings boshsettings.Settings, platform boshplatform.Platform) (ping mountDiskAction) {
	ping.settings = settings
	ping.platform = platform
	return
}

func (a mountDiskAction) Run(payloadBytes []byte) (value interface{}, err error) {
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

	err = a.platform.MountPersistentDisk(devicePath, filepath.Join(boshsettings.VCAP_BASE_DIR, "store"))
	if err != nil {
		err = bosherr.WrapError(err, "Mounting persistent disk")
		return
	}

	value = make(map[string]string)
	return
}
