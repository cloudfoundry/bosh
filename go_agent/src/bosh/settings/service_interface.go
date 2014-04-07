package settings

import (
	boshsys "bosh/system"
)

type ServiceProvider interface {
	NewService(boshsys.FileSystem, string, SettingsFetcher) Service
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
