package settings

import (
	"encoding/json"
	"path/filepath"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshsys "bosh/system"
)

const concreteServiceLogTag = "concreteService"

type SettingsFetcher func() (Settings, error)

type concreteServiceProvider struct{}

func NewServiceProvider() concreteServiceProvider {
	return concreteServiceProvider{}
}

func (provider concreteServiceProvider) NewService(
	fs boshsys.FileSystem,
	dir string,
	fetcher SettingsFetcher,
	logger boshlog.Logger,
) Service {
	return NewService(fs, filepath.Join(dir, "settings.json"), fetcher, logger)
}

type concreteService struct {
	fs              boshsys.FileSystem
	settingsPath    string
	settings        Settings
	settingsFetcher SettingsFetcher
	logger          boshlog.Logger
}

func NewService(
	fs boshsys.FileSystem,
	settingsPath string,
	settingsFetcher SettingsFetcher,
	logger boshlog.Logger,
) (service Service) {
	return &concreteService{
		fs:              fs,
		settingsPath:    settingsPath,
		settings:        Settings{},
		settingsFetcher: settingsFetcher,
		logger:          logger,
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
	service.logger.Debug(concreteServiceLogTag, "Loading settings from fetcher")

	newSettings, fetchErr := service.settingsFetcher()
	if fetchErr != nil {
		service.logger.Error(concreteServiceLogTag, "Failed to load settings via fetcher: %v", fetchErr)

		existingSettingsJSON, readError := service.fs.ReadFile(service.settingsPath)
		if readError != nil {
			return bosherr.WrapError(fetchErr, "Invoking settings fetcher")
		}

		service.logger.Debug(concreteServiceLogTag, "Successfully received settings from file")

		return json.Unmarshal(existingSettingsJSON, &service.settings)
	}

	service.logger.Debug(concreteServiceLogTag, "Successfully received settings from fetcher")

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
