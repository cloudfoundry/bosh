package platform

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
