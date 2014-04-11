package settings

import (
	boshlog "bosh/logger"
	boshsys "bosh/system"
)

type ServiceProvider interface {
	NewService(boshsys.FileSystem, string, SettingsFetcher, boshlog.Logger) Service
}

type Service interface {
	LoadSettings() error
	GetSettings() Settings

	InvalidateSettings() error

	GetBlobstore() Blobstore
	GetAgentID() string
	GetVM() VM
	GetMbusURL() string
	GetDisks() Disks
	GetDefaultIP() (string, bool)
	GetIPs() []string
}
