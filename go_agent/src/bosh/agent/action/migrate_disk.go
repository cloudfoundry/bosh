package action

import (
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type migrateDiskAction struct {
	settings boshsettings.DiskSettings
	platform boshplatform.Platform
}

func newMigrateDisk(settings boshsettings.DiskSettings, platform boshplatform.Platform) (action migrateDiskAction) {
	action.settings = settings
	action.platform = platform
	return
}

func (a migrateDiskAction) Run(payloadBytes []byte) (value interface{}, err error) {
	fromMountPoint := a.settings.GetStoreMountPoint()
	toMountPoint := a.settings.GetStoreMigrationMountPoint()

	err = a.platform.MigratePersistentDisk(fromMountPoint, toMountPoint)
	if err != nil {
		return
	}

	value = map[string]string{}
	return
}
