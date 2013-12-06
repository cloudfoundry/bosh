package settings

import "path/filepath"

type SettingsFetcher func() (settings Settings, err error)

type concreteService struct {
	settings        Settings
	settingsFetcher SettingsFetcher
}

func NewService(initialSettings Settings, settingsFetcher SettingsFetcher) (service Service) {
	return &concreteService{
		settings:        initialSettings,
		settingsFetcher: settingsFetcher,
	}
}

func (service *concreteService) GetBlobstore() Blobstore {
	return service.settings.Blobstore
}

func (service *concreteService) GetAgentId() string {
	return service.settings.AgentId
}

func (service *concreteService) GetVm() Vm {
	return service.settings.Vm
}

func (service *concreteService) GetMbusUrl() string {
	return service.settings.Mbus
}

func (service *concreteService) GetDisks() Disks {
	return service.settings.Disks
}

func (service *concreteService) GetStoreMountPoint() string {
	return filepath.Join(VCAP_BASE_DIR, "store")
}

func (service *concreteService) GetStoreMigrationMountPoint() string {
	return filepath.Join(VCAP_BASE_DIR, "store_migration_target")
}

func (service *concreteService) GetDefaultIp() (ip string, found bool) {
	return service.settings.Networks.DefaultIp()
}
