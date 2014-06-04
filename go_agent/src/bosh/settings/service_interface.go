package settings

import (
	boshlog "bosh/logger"
	boshsys "bosh/system"
)

type ServiceProvider interface {
	NewService(
		boshsys.FileSystem,
		string,
		SettingsFetcher,
		DefaultNetworkDelegate,
		boshlog.Logger,
	) Service
}

type Service interface {
	LoadSettings() error
	GetSettings() Settings
	InvalidateSettings() error
}
