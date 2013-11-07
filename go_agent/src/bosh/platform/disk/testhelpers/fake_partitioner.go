package testhelpers

import (
	boshdisk "bosh/platform/disk"
)

type FakePartitioner struct {
	PartitionDevicePath string
	PartitionPartitions []boshdisk.Partition
}

func (p *FakePartitioner) Partition(devicePath string, partitions []boshdisk.Partition) (err error) {
	p.PartitionDevicePath = devicePath
	p.PartitionPartitions = partitions
	return
}
