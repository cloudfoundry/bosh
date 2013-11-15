package stats

import sigar "github.com/cloudfoundry/gosigar"

type sigarStatsCollector struct {
}

func NewSigarStatsCollector() (collector sigarStatsCollector) {
	return
}

func (s sigarStatsCollector) GetCpuLoad() (load CpuLoad, err error) {
	l := sigar.LoadAverage{}
	err = l.Get()
	if err != nil {
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
		return
	}

	stats.User = cpu.User
	stats.Sys = cpu.Sys
	stats.Wait = cpu.Wait
	stats.Total = cpu.Total()

	return
}

func (s sigarStatsCollector) GetMemStats() (stats MemStats, err error) {
	mem := sigar.Mem{}
	err = mem.Get()
	if err != nil {
		return
	}

	stats.Total = mem.Total
	stats.Used = mem.Used

	return
}

func (s sigarStatsCollector) GetSwapStats() (stats MemStats, err error) {
	swap := sigar.Swap{}
	err = swap.Get()
	if err != nil {
		return
	}

	stats.Total = swap.Total
	stats.Used = swap.Used

	return
}

func (s sigarStatsCollector) GetDiskStats(mountedPath string) (stats DiskStats, err error) {
	fsUsage := sigar.FileSystemUsage{}
	err = fsUsage.Get(mountedPath)
	if err != nil {
		return
	}

	stats.Total = fsUsage.Total
	stats.Used = fsUsage.Used
	stats.InodeTotal = fsUsage.Files
	stats.InodeUsed = fsUsage.Files - fsUsage.FreeFiles

	return
}
