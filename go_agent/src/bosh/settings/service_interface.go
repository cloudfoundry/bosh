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

	// GetSettings does not return error
	// because without settings Agent cannot start.
	GetSettings() Settings

	InvalidateSettings() error
}
