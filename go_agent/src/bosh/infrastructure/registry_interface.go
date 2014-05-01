package infrastructure

import (
	boshsettings "bosh/settings"
)

type Registry interface {
	GetSettingsAtURL(settingsURL string) (boshsettings.Settings, error)
}
