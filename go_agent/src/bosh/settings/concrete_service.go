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

func (service *concreteService) InvalidateSettings() error {
	err := service.fs.RemoveAll(service.settingsPath)
	if err != nil {
		return bosherr.WrapError(err, "Removing settings file")
	}

	return nil
}

func (service *concreteService) LoadSettings() error {
	newSettings, fetchErr := service.settingsFetcher()
	if fetchErr != nil {
		existingSettingsJSON, readError := service.fs.ReadFile(service.settingsPath)
		if readError != nil {
			return bosherr.WrapError(fetchErr, "Invoking settings fetcher")
		}

		return json.Unmarshal(existingSettingsJSON, &service.settings)
	}

	service.settings = newSettings

	newSettingsJSON, err := json.Marshal(newSettings)
	if err != nil {
		return bosherr.WrapError(err, "Marshalling settings json")
	}

	err = service.fs.WriteFile(service.settingsPath, newSettingsJSON)
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

func (service concreteService) GetAgentID() string {
	return service.settings.AgentID
}

func (service concreteService) GetVM() VM {
	return service.settings.VM
}

func (service concreteService) GetMbusURL() string {
	return service.settings.Mbus
}

func (service concreteService) GetDisks() Disks {
	return service.settings.Disks
}

func (service concreteService) GetDefaultIP() (ip string, found bool) {
	return service.settings.Networks.DefaultIP()
}

func (service concreteService) GetIPs() (ips []string) {
	return service.settings.Networks.IPs()
}
