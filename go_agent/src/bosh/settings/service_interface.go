package settings

import (
	boshsys "bosh/system"
)

type ServiceProvider interface {
	NewService(boshsys.FileSystem, string, SettingsFetcher) Service
}

type Service interface {
	FetchInitial() error
	ForceNextFetchInitialToRefresh() error

	Refresh() error

	GetSettings() Settings

	GetBlobstore() Blobstore
	GetAgentId() string
	GetVm() Vm
	GetMbusUrl() string
	GetDisks() Disks
	GetDefaultIp() (string, bool)
	GetIps() []string
}
