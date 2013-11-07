package testhelpers

import (
	boshdisk "bosh/platform/disk"
)

type FakePartitioner struct {
	GetDeviceSizeInBlocksSizes map[string]uint64
	PartitionDevicePath        string
	PartitionPartitions        []boshdisk.Partition
}

func (p *FakePartitioner) Partition(devicePath string, partitions []boshdisk.Partition) (err error) {
	p.PartitionDevicePath = devicePath
	p.PartitionPartitions = partitions
	return
}

func (p *FakePartitioner) GetDeviceSizeInBlocks(devicePath string) (size uint64, err error) {
	size = p.GetDeviceSizeInBlocksSizes[devicePath]
	return
}
