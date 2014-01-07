package settings

import (
	bosherr "bosh/errors"
)

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

func (service *concreteService) Refresh() (err error) {
	newSettings, err := service.settingsFetcher()
	if err != nil {
		err = bosherr.WrapError(err, "Invoking settings fetcher")
		return
	}

	service.settings = newSettings
	return
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

func (service *concreteService) GetDefaultIp() (ip string, found bool) {
	return service.settings.Networks.DefaultIp()
}

func (service *concreteService) GetIps() (ips []string) {
	return service.settings.Networks.Ips()
}
