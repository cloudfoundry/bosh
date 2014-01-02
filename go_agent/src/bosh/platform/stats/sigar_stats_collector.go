package stats

import (
	bosherr "bosh/errors"
	sigar "github.com/cloudfoundry/gosigar"
)

type sigarStatsCollector struct {
}

func NewSigarStatsCollector() (collector StatsCollector) {
	return sigarStatsCollector{}
}

func (s sigarStatsCollector) GetCpuLoad() (load CpuLoad, err error) {
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

func (s sigarStatsCollector) GetCpuStats() (stats CpuStats, err error) {
	cpu := sigar.Cpu{}
	err = cpu.Get()
	if err != nil {
		err = bosherr.WrapError(err, "Getting Sigar Cpu")
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
	usage.Used = mem.Used

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
