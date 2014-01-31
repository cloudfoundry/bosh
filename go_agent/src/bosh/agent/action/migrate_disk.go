package action

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshdirs "bosh/settings/directories"
)

type migrateDiskAction struct {
	platform    boshplatform.Platform
	dirProvider boshdirs.DirectoriesProvider
}

func newMigrateDisk(platform boshplatform.Platform, dirProvider boshdirs.DirectoriesProvider) (action migrateDiskAction) {
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
