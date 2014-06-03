package action

import (
	"errors"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type ListDiskAction struct {
	settingsService boshsettings.Service
	platform        boshplatform.Platform
	logger          boshlog.Logger
}

func NewListDisk(
	settingsService boshsettings.Service,
	platform boshplatform.Platform,
	logger boshlog.Logger,
) (action ListDiskAction) {
	action.settingsService = settingsService
	action.platform = platform
	action.logger = logger
	return
}

func (a ListDiskAction) IsAsynchronous() bool {
	return false
}

func (a ListDiskAction) IsPersistent() bool {
	return false
}

func (a ListDiskAction) Run() (value interface{}, err error) {
	settings := a.settingsService.GetSettings()
	volumeIDs := []string{}

	for volumeID, devicePath := range settings.Disks.Persistent {
		var isMounted bool

		isMounted, err = a.platform.IsPersistentDiskMounted(devicePath)
		if err != nil {
			bosherr.WrapError(err, "Checking whether device %s is mounted", devicePath)
			return
		}

		if isMounted {
			volumeIDs = append(volumeIDs, volumeID)
		} else {
			a.logger.Debug("list-disk-action", "Not mounted", volumeID)
		}
	}

	value = volumeIDs
	return
}

func (a ListDiskAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a ListDiskAction) Cancel() error {
	return errors.New("not supported")
}
