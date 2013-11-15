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

type MemStats struct {
	Used  uint64
	Total uint64
}

type DiskStats struct {
	Used       uint64
	Total      uint64
	InodeUsed  uint64
	InodeTotal uint64
}

type StatsCollector interface {
	GetCpuLoad() (load CpuLoad, err error)
	GetCpuStats() (stats CpuStats, err error)
	GetMemStats() (stats MemStats, err error)
	GetSwapStats() (stats MemStats, err error)
	GetDiskStats(devicePath string) (stats DiskStats, err error)
}
