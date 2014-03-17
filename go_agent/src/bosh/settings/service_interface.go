package settings

type Service interface {
	FetchInitial() error
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
