package fakes

import (
	boshdisk "bosh/platform/disk"
)

type FakePartitioner struct {
	PartitionCalled     bool
	PartitionDevicePath string
	PartitionPartitions []boshdisk.Partition

	GetDeviceSizeInMbSizes map[string]uint64
}

func (p *FakePartitioner) Partition(devicePath string, partitions []boshdisk.Partition) (err error) {
	p.PartitionCalled = true
	p.PartitionDevicePath = devicePath
	p.PartitionPartitions = partitions
	return
}

func (p *FakePartitioner) GetDeviceSizeInMb(devicePath string) (size uint64, err error) {
	size = p.GetDeviceSizeInMbSizes[devicePath]
	return
}
