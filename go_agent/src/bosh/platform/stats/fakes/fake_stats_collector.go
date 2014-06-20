package fakes

import (
	"errors"
	"time"

	boshstats "bosh/platform/stats"
)

type FakeStatsCollector struct {
	StartCollectingCPUStats boshstats.CPUStats

	CPULoad  boshstats.CPULoad
	cpuStats boshstats.CPUStats

	MemStats  boshstats.Usage
	SwapStats boshstats.Usage
	DiskStats map[string]boshstats.DiskStats
}

func (c *FakeStatsCollector) StartCollecting(collectionInterval time.Duration, latestGotUpdated chan struct{}) {
	c.cpuStats = c.StartCollectingCPUStats
}

func (c *FakeStatsCollector) GetCPULoad() (load boshstats.CPULoad, err error) {
	load = c.CPULoad
	return
}

func (c *FakeStatsCollector) GetCPUStats() (stats boshstats.CPUStats, err error) {
	stats = c.cpuStats
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
