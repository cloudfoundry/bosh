package stats

type CpuLoad struct {
	One     float64
	Five    float64
	Fifteen float64
}

type CpuStats struct {
	User  uint64
	Sys   uint64
	Wait  uint64
	Total uint64
}

type Usage struct {
	Used  uint64
	Total uint64
}

type DiskStats struct {
	DiskUsage  Usage
	InodeUsage Usage
}

type StatsCollector interface {
	GetCpuLoad() (load CpuLoad, err error)
	GetCpuStats() (stats CpuStats, err error)
	GetMemStats() (usage Usage, err error)
	GetSwapStats() (usage Usage, err error)
	GetDiskStats(mountedPath string) (stats DiskStats, err error)
}

func (cpuStats CpuStats) UserPercent() Percentage {
	return Percentage{cpuStats.User, cpuStats.Total}
}

func (cpuStats CpuStats) SysPercent() Percentage {
	return Percentage{cpuStats.Sys, cpuStats.Total}
}

func (cpuStats CpuStats) WaitPercent() Percentage {
	return Percentage{cpuStats.Wait, cpuStats.Total}
}

func (usage Usage) Percent() Percentage {
	return Percentage{usage.Used, usage.Total}
}
