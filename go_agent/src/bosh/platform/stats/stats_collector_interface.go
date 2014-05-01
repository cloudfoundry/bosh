package stats

type CPULoad struct {
	One     float64
	Five    float64
	Fifteen float64
}

type CPUStats struct {
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
	GetCPULoad() (load CPULoad, err error)
	GetCPUStats() (stats CPUStats, err error)
	GetMemStats() (usage Usage, err error)
	GetSwapStats() (usage Usage, err error)
	GetDiskStats(mountedPath string) (stats DiskStats, err error)
}

func (cpuStats CPUStats) UserPercent() Percentage {
	return NewPercentage(cpuStats.User, cpuStats.Total)
}

func (cpuStats CPUStats) SysPercent() Percentage {
	return NewPercentage(cpuStats.Sys, cpuStats.Total)
}

func (cpuStats CPUStats) WaitPercent() Percentage {
	return NewPercentage(cpuStats.Wait, cpuStats.Total)
}

func (usage Usage) Percent() Percentage {
	return NewPercentage(usage.Used, usage.Total)
}
