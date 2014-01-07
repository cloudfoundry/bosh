package settings

type Service interface {
	Refresh() (err error)

	GetBlobstore() Blobstore
	GetAgentId() string
	GetVm() Vm
	GetMbusUrl() string
	GetDisks() Disks
	GetDefaultIp() (ip string, found bool)
	GetIps() (ips []string)
}
