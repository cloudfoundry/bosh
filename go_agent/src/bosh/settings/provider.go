package settings

import "path/filepath"

type Provider struct {
	settings Settings
}

func NewProvider(settings Settings) (provider *Provider) {
	provider = new(Provider)
	provider.settings = settings
	return
}

type VmSettings interface {
	GetAgentId() string
	GetVm() Vm
}

type MbusSettings interface {
	VmSettings
	GetMbusUrl() string
}

type DiskSettings interface {
	GetDisks() Disks
	GetStoreMountPoint() string
	GetStoreMigrationMountPoint() string
}

type NetworkSettings interface {
	GetDefaultIp() (ip string, found bool)
}

func (provider *Provider) GetBlobstore() Blobstore {
	return provider.settings.Blobstore
}

func (provider *Provider) GetAgentId() string {
	return provider.settings.AgentId
}

func (provider *Provider) GetVm() Vm {
	return provider.settings.Vm
}

func (provider *Provider) GetMbusUrl() string {
	return provider.settings.Mbus
}

func (provider *Provider) GetDisks() Disks {
	return provider.settings.Disks
}

func (provider *Provider) GetStoreMountPoint() string {
	return filepath.Join(VCAP_BASE_DIR, "store")
}

func (provider *Provider) GetStoreMigrationMountPoint() string {
	return filepath.Join(VCAP_BASE_DIR, "store_migration_target")
}

func (provider *Provider) GetDefaultIp() (ip string, found bool) {
	return provider.settings.Networks.DefaultIp()
}
