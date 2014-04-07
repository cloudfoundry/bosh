package fakes

import (
	boshsettings "bosh/settings"
	boshsys "bosh/system"
)

type FakeSettingsServiceProvider struct {
	NewServiceFs              boshsys.FileSystem
	NewServiceDir             string
	NewServiceFetcher         boshsettings.SettingsFetcher
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
) boshsettings.Service {
	provider.NewServiceFs = fs
	provider.NewServiceDir = dir
	provider.NewServiceFetcher = fetcher
	return provider.NewServiceSettingsService
}

type FakeSettingsService struct {
	LoadSettingsError  error
	SettingsWereLoaded bool

	InvalidateSettingsError error
	SettingsWereInvalidated bool

	Settings boshsettings.Settings

	Blobstore boshsettings.Blobstore
	AgentID   string
	VM        boshsettings.VM
	MbusURL   string
	Disks     boshsettings.Disks
	DefaultIP string
	IPs       []string
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

func (service FakeSettingsService) GetBlobstore() boshsettings.Blobstore {
	return service.Blobstore
}

func (service FakeSettingsService) GetAgentID() string {
	return service.AgentID
}

func (service FakeSettingsService) GetVM() boshsettings.VM {
	return service.VM
}

func (service FakeSettingsService) GetMbusURL() string {
	return service.MbusURL
}

func (service FakeSettingsService) GetDisks() boshsettings.Disks {
	return service.Disks
}

func (service FakeSettingsService) GetDefaultIP() (string, bool) {
	return service.DefaultIP, service.DefaultIP != ""
}

func (service FakeSettingsService) GetIPs() []string {
	return service.IPs
}
