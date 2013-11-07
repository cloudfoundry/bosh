package disk

type PartitionType string

const (
	PartitionTypeSwap  PartitionType = "swap"
	PartitionTypeLinux               = "linux"
	PartitionTypeEmpty               = "empty"
)

type Partition struct {
	SizeInBlocks uint64
	Type         PartitionType
}

type Partitioner interface {
	Partition(devicePath string, partitions []Partition) (err error)
	GetDeviceSizeInBlocks(devicePath string) (size uint64, err error)
}
