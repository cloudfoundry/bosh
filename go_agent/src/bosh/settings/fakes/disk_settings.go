package fakes

import (
	boshsettings "bosh/settings"
	"path/filepath"
)

type FakeDiskSettings struct {
	Disks boshsettings.Disks
}

func (settings *FakeDiskSettings) GetDisks() boshsettings.Disks {
	return settings.Disks
}

func (settings *FakeDiskSettings) GetStoreMountPoint() string {
	return filepath.Join(boshsettings.VCAP_BASE_DIR, "store")
}

func (settings *FakeDiskSettings) GetStoreMigrationMountPoint() string {
	return filepath.Join(boshsettings.VCAP_BASE_DIR, "store_migration_target")
}
