package action

import (
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type migrateDiskAction struct {
	settings boshsettings.Service
	platform boshplatform.Platform
}

func newMigrateDisk(settings boshsettings.Service, platform boshplatform.Platform) (action migrateDiskAction) {
	action.settings = settings
	action.platform = platform
	return
}

func (a migrateDiskAction) IsAsynchronous() bool {
	return true
}

func (a migrateDiskAction) Run() (value interface{}, err error) {
	fromMountPoint := a.settings.GetStoreMountPoint()
	toMountPoint := a.settings.GetStoreMigrationMountPoint()

	err = a.platform.MigratePersistentDisk(fromMountPoint, toMountPoint)
	if err != nil {
		return
	}

	value = map[string]string{}
	return
}
