package disk

type Mount struct {
	PartitionPath string
	MountPoint    string
}

type MountsSearcher interface {
	SearchMounts() ([]Mount, error)
}
