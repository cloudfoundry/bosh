package settings

import (
	"encoding/json"
	"path/filepath"

	bosherr "bosh/errors"
	boshsys "bosh/system"
)

type SettingsFetcher func() (Settings, error)

type concreteServiceProvider struct{}

func NewServiceProvider() concreteServiceProvider {
	return concreteServiceProvider{}
}

func (provider concreteServiceProvider) NewService(
	fs boshsys.FileSystem,
	dir string,
	fetcher SettingsFetcher,
) Service {
	return NewService(fs, filepath.Join(dir, "settings.json"), fetcher)
}

type concreteService struct {
	fs              boshsys.FileSystem
	settingsPath    string
	settings        Settings
	settingsFetcher SettingsFetcher
}

func NewService(
	fs boshsys.FileSystem,
	settingsPath string,
	settingsFetcher SettingsFetcher,
) (service Service) {
	return &concreteService{
		fs:              fs,
		settingsPath:    settingsPath,
		settings:        Settings{},
		settingsFetcher: settingsFetcher,
	}
}

func (service *concreteService) FetchInitial() error {
	existingSettingsJson, readError := service.fs.ReadFile(service.settingsPath)
	if readError != nil {
		return service.Refresh()
	}

	return json.Unmarshal(existingSettingsJson, &service.settings)
}

func (service *concreteService) ForceNextFetchInitialToRefresh() error {
	err := service.fs.RemoveAll(service.settingsPath)
	if err != nil {
		return bosherr.WrapError(err, "Removing settings file")
	}

	return nil
}

func (service *concreteService) Refresh() error {
	newSettings, err := service.settingsFetcher()
	if err != nil {
		return bosherr.WrapError(err, "Invoking settings fetcher")
	}

	service.settings = newSettings

	newSettingsJson, _ := json.Marshal(newSettings)
	if err != nil {
		return bosherr.WrapError(err, "Marshalling settings json")
	}

	err = service.fs.WriteFile(service.settingsPath, newSettingsJson)
	if err != nil {
		return bosherr.WrapError(err, "Writing setting json")
	}

	return nil
}

func (service concreteService) GetSettings() Settings {
	return service.settings
}

func (service concreteService) GetBlobstore() Blobstore {
	return service.settings.Blobstore
}

func (service concreteService) GetAgentId() string {
	return service.settings.AgentId
}

func (service concreteService) GetVm() Vm {
	return service.settings.Vm
}

func (service concreteService) GetMbusUrl() string {
	return service.settings.Mbus
}

func (service concreteService) GetDisks() Disks {
	return service.settings.Disks
}

func (service concreteService) GetDefaultIp() (ip string, found bool) {
	return service.settings.Networks.DefaultIp()
}

func (service concreteService) GetIps() (ips []string) {
	return service.settings.Networks.Ips()
}
