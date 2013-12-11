package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type listDiskAction struct {
	settings boshsettings.Service
	platform boshplatform.Platform
}

func newListDisk(settings boshsettings.Service, platform boshplatform.Platform) (action listDiskAction) {
	action.settings = settings
	action.platform = platform
	return
}

func (a listDiskAction) IsAsynchronous() bool {
	return false
}

func (a listDiskAction) Run() (value interface{}, err error) {
	disks := a.settings.GetDisks()
	volumeIds := []string{}

	for volumeId, devicePath := range disks.Persistent {
		var isMounted bool
		isMounted, err = a.platform.IsDevicePathMounted(devicePath)
		if err != nil {
			bosherr.WrapError(err, "Checking whether device %s is mounted", devicePath)
			return
		}

		if isMounted {
			volumeIds = append(volumeIds, volumeId)
		}
	}

	value = volumeIds
	return
}
