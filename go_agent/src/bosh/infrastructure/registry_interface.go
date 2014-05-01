package infrastructure

import (
	boshsettings "bosh/settings"
)

type Registry interface {
	GetSettings() (boshsettings.Settings, error)
}
