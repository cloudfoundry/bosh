package fakes

import (
	boshlog "bosh/logger"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
)

type FakeSettingsServiceProvider struct {
	NewServiceFs              boshsys.FileSystem
	NewServiceDir             string
	NewServiceFetcher         boshsettings.SettingsFetcher
	NewDefaultNetworkResolver boshsettings.DefaultNetworkDelegate
	NewServiceSettingsService *FakeSettingsService
}

func NewServiceProvider() *FakeSettingsServiceProvider {
	return &FakeSettingsServiceProvider{
		NewServiceSettingsService: &FakeSettingsService{},
	}
}

func (provider *FakeSettingsServiceProvider) NewService(
	fs boshsys.FileSystem,
	dir string,
	fetcher boshsettings.SettingsFetcher,
	defaultNetworkResolver boshsettings.DefaultNetworkDelegate,
	logger boshlog.Logger,
) boshsettings.Service {
	provider.NewServiceFs = fs
	provider.NewServiceDir = dir
	provider.NewServiceFetcher = fetcher
	provider.NewDefaultNetworkResolver = defaultNetworkResolver
	return provider.NewServiceSettingsService
}

type FakeSettingsService struct {
	LoadSettingsError  error
	SettingsWereLoaded bool

	InvalidateSettingsError error
	SettingsWereInvalidated bool

	Settings boshsettings.Settings
}

func (service *FakeSettingsService) InvalidateSettings() error {
	service.SettingsWereInvalidated = true
	return service.InvalidateSettingsError
}

func (service *FakeSettingsService) LoadSettings() error {
	service.SettingsWereLoaded = true
	return service.LoadSettingsError
}

func (service FakeSettingsService) GetSettings() boshsettings.Settings {
	return service.Settings
}
