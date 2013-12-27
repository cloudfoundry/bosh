package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
)

type migrateDiskAction struct {
	settings    boshsettings.Service
	platform    boshplatform.Platform
	dirProvider boshdirs.DirectoriesProvider
}

func newMigrateDisk(settings boshsettings.Service, platform boshplatform.Platform, dirProvider boshdirs.DirectoriesProvider) (action migrateDiskAction) {
	action.settings = settings
	action.platform = platform
	action.dirProvider = dirProvider
	return
}

func (a migrateDiskAction) IsAsynchronous() bool {
	return true
}

func (a migrateDiskAction) Run() (value interface{}, err error) {
	err = a.platform.MigratePersistentDisk(a.dirProvider.StoreDir(), a.dirProvider.StoreMigrationDir())
	if err != nil {
		err = bosherr.WrapError(err, "Migrating persistent disk")
		return
	}

	value = map[string]string{}
	return
}
