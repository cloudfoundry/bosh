package fakes

import (
	boshsettings "bosh/settings"
)

type FakeDiskSettings struct {
	Disks boshsettings.Disks
}

func (settings *FakeDiskSettings) GetDisks() boshsettings.Disks {
	return settings.Disks
}
