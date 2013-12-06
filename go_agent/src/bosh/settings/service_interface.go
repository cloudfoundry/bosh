package settings

type Service interface {
	GetBlobstore() Blobstore
	GetAgentId() string
	GetVm() Vm
	GetMbusUrl() string
	GetDisks() Disks
	GetStoreMountPoint() string
	GetStoreMigrationMountPoint() string
	GetDefaultIp() (ip string, found bool)
}
