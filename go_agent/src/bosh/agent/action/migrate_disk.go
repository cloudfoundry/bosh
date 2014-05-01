package action

import (
	"errors"

	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshdirs "bosh/settings/directories"
)

type MigrateDiskAction struct {
	platform    boshplatform.Platform
	dirProvider boshdirs.DirectoriesProvider
}

func NewMigrateDisk(
	platform boshplatform.Platform,
	dirProvider boshdirs.DirectoriesProvider,
) (action MigrateDiskAction) {
	action.platform = platform
	action.dirProvider = dirProvider
	return
}

func (a MigrateDiskAction) IsAsynchronous() bool {
	return true
}

func (a MigrateDiskAction) IsPersistent() bool {
	return false
}

func (a MigrateDiskAction) Run() (value interface{}, err error) {
	err = a.platform.MigratePersistentDisk(a.dirProvider.StoreDir(), a.dirProvider.StoreMigrationDir())
	if err != nil {
		err = bosherr.WrapError(err, "Migrating persistent disk")
		return
	}

	value = map[string]string{}
	return
}

func (a MigrateDiskAction) Resume() (interface{}, error) {
	return nil, errors.New("not supported")
}

func (a MigrateDiskAction) Cancel() error {
	return errors.New("not supported")
}
