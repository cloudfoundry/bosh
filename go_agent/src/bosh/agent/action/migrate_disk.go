package action

import (
	bosherr "bosh/errors"
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
	fromMountPoint := boshsettings.VCAP_STORE_DIR
	toMountPoint := boshsettings.VCAP_STORE_MIGRATION_DIR

	err = a.platform.MigratePersistentDisk(fromMountPoint, toMountPoint)
	if err != nil {
		err = bosherr.WrapError(err, "Migrating persistent disk")
		return
	}

	value = map[string]string{}
	return
}
