package fakes

import (
	boshdisk "bosh/platform/disk"
)

type FakePartitioner struct {
	GetDeviceSizeInMbSizes map[string]uint64
	PartitionDevicePath    string
	PartitionPartitions    []boshdisk.Partition
}

func (p *FakePartitioner) Partition(devicePath string, partitions []boshdisk.Partition) (err error) {
	p.PartitionDevicePath = devicePath
	p.PartitionPartitions = partitions
	return
}

func (p *FakePartitioner) GetDeviceSizeInMb(devicePath string) (size uint64, err error) {
	size = p.GetDeviceSizeInMbSizes[devicePath]
	return
}
