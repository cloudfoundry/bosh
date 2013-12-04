package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	"path/filepath"
)

type mountDiskAction struct {
	settings boshsettings.Settings
	platform boshplatform.Platform
}

func newMountDisk(settings boshsettings.Settings, platform boshplatform.Platform) (mountDisk mountDiskAction) {
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

	err = a.platform.MountPersistentDisk(devicePath, filepath.Join(boshsettings.VCAP_BASE_DIR, "store"))
	if err != nil {
		err = bosherr.WrapError(err, "Mounting persistent disk")
		return
	}

	value = make(map[string]string)
	return
}
