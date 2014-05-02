package fakes

import (
	boshsettings "bosh/settings"
)

type FakeRegistry struct {
	Settings       boshsettings.Settings
	GetSettingsErr error
}

func (r *FakeRegistry) GetSettings() (boshsettings.Settings, error) {
	return r.Settings, r.GetSettingsErr
}
