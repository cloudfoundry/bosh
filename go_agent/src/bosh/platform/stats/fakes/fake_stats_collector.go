package fakes

import (
	boshstats "bosh/platform/stats"
	"errors"
)

type FakeStatsCollector struct {
	CpuLoad   boshstats.CpuLoad
	CpuStats  boshstats.CpuStats
	MemStats  boshstats.Usage
	SwapStats boshstats.Usage
	DiskStats map[string]boshstats.DiskStats
}

func (c *FakeStatsCollector) GetCpuLoad() (load boshstats.CpuLoad, err error) {
	load = c.CpuLoad
	return
}

func (c *FakeStatsCollector) GetCpuStats() (stats boshstats.CpuStats, err error) {
	stats = c.CpuStats
	return
}

func (c *FakeStatsCollector) GetMemStats() (usage boshstats.Usage, err error) {
	usage = c.MemStats
	return
}

func (c *FakeStatsCollector) GetSwapStats() (usage boshstats.Usage, err error) {
	usage = c.SwapStats
	return
}

func (c *FakeStatsCollector) GetDiskStats(devicePath string) (stats boshstats.DiskStats, err error) {
	stats, found := c.DiskStats[devicePath]
	if !found {
		err = errors.New("Disk not found")
	}
	return
}
