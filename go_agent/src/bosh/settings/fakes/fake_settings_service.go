package fakes

import (
	boshsettings "bosh/settings"
)

type FakeSettingsService struct {
	SettingsWereRefreshed bool

	Blobstore boshsettings.Blobstore
	AgentId   string
	Vm        boshsettings.Vm
	MbusUrl   string
	Disks     boshsettings.Disks
	DefaultIp string
	Ips       []string
}

func (service *FakeSettingsService) Refresh() (err error) {
	service.SettingsWereRefreshed = true
	return
}

func (service *FakeSettingsService) GetBlobstore() boshsettings.Blobstore {
	return service.Blobstore
}

func (service *FakeSettingsService) GetAgentId() string {
	return service.AgentId
}

func (service *FakeSettingsService) GetVm() boshsettings.Vm {
	return service.Vm
}

func (service *FakeSettingsService) GetMbusUrl() string {
	return service.MbusUrl
}

func (service *FakeSettingsService) GetDisks() boshsettings.Disks {
	return service.Disks
}

func (service *FakeSettingsService) GetDefaultIp() (ip string, found bool) {
	return service.DefaultIp, service.DefaultIp != ""
}

func (service *FakeSettingsService) GetIps() []string {
	return service.Ips
}
