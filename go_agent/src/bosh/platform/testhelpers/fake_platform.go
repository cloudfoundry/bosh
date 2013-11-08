package testhelpers

import (
	boshstats "bosh/platform/stats"
	teststats "bosh/platform/stats/testhelpers"
	boshsettings "bosh/settings"
)

type FakePlatform struct {
	SetupEphemeralDiskWithPathDevicePath string
	SetupEphemeralDiskWithPathMountPoint string
	FakeStatsCollector                   *teststats.FakeStatsCollector
}

func NewFakePlatform() (platform FakePlatform) {
	platform.FakeStatsCollector = &teststats.FakeStatsCollector{}
	return
}

func (p *FakePlatform) GetStatsCollector() (collector boshstats.StatsCollector) {
	return p.FakeStatsCollector
}

func (p *FakePlatform) SetupSsh(publicKey, username string) (err error) {
	return
}

func (p *FakePlatform) SetupDhcp(networks boshsettings.Networks) (err error) {
	return
}

func (p *FakePlatform) SetupEphemeralDiskWithPath(devicePath, mountPoint string) (err error) {
	p.SetupEphemeralDiskWithPathDevicePath = devicePath
	p.SetupEphemeralDiskWithPathMountPoint = mountPoint
	return
}
