package fakes

import (
	boshstats "bosh/platform/stats"
	"errors"
)

type FakeStatsCollector struct {
	CPULoad   boshstats.CPULoad
	CPUStats  boshstats.CPUStats
	MemStats  boshstats.Usage
	SwapStats boshstats.Usage
	DiskStats map[string]boshstats.DiskStats
}

func (c *FakeStatsCollector) GetCPULoad() (load boshstats.CPULoad, err error) {
	load = c.CPULoad
	return
}

func (c *FakeStatsCollector) GetCPUStats() (stats boshstats.CPUStats, err error) {
	stats = c.CPUStats
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
