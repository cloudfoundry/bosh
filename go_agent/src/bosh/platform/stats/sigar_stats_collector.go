package stats

import (
	sigar "github.com/cloudfoundry/gosigar"

	bosherr "bosh/errors"
)

type sigarStatsCollector struct{}

func NewSigarStatsCollector() StatsCollector {
	return sigarStatsCollector{}
}

func (s sigarStatsCollector) GetCPULoad() (load CPULoad, err error) {
	l := sigar.LoadAverage{}
	err = l.Get()
	if err != nil {
		err = bosherr.WrapError(err, "Getting Sigar Load Average")
		return
	}

	load.One = l.One
	load.Five = l.Five
	load.Fifteen = l.Fifteen

	return
}

func (s sigarStatsCollector) GetCPUStats() (stats CPUStats, err error) {
	cpu := sigar.Cpu{}
	err = cpu.Get()
	if err != nil {
		err = bosherr.WrapError(err, "Getting Sigar CPU")
		return
	}

	stats.User = cpu.User
	stats.Sys = cpu.Sys
	stats.Wait = cpu.Wait
	stats.Total = cpu.Total()

	return
}

func (s sigarStatsCollector) GetMemStats() (usage Usage, err error) {
	mem := sigar.Mem{}
	err = mem.Get()
	if err != nil {
		err = bosherr.WrapError(err, "Getting Sigar Mem")
		return
	}

	usage.Total = mem.Total

	// actual_used = mem->used - (kern_buffers + kern_cached)
	// (https://github.com/hyperic/sigar/blob/1898438/src/os/linux/linux_sigar.c#L344)
	usage.Used = mem.ActualUsed

	return
}

func (s sigarStatsCollector) GetSwapStats() (usage Usage, err error) {
	swap := sigar.Swap{}
	err = swap.Get()
	if err != nil {
		err = bosherr.WrapError(err, "Getting Sigar Swap")
		return
	}

	usage.Total = swap.Total
	usage.Used = swap.Used

	return
}

func (s sigarStatsCollector) GetDiskStats(mountedPath string) (stats DiskStats, err error) {
	fsUsage := sigar.FileSystemUsage{}
	err = fsUsage.Get(mountedPath)
	if err != nil {
		err = bosherr.WrapError(err, "Getting Sigar File System Usage")
		return
	}

	stats.DiskUsage.Total = fsUsage.Total
	stats.DiskUsage.Used = fsUsage.Used
	stats.InodeUsage.Total = fsUsage.Files
	stats.InodeUsage.Used = fsUsage.Files - fsUsage.FreeFiles

	return
}
