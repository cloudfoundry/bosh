package fakes

import (
	boshdisk "bosh/platform/disk"
)

type FakeFormatter struct {
	FormatPartitionPaths []string
	FormatFsTypes        []boshdisk.FileSystemType
}

func (p *FakeFormatter) Format(partitionPath string, fsType boshdisk.FileSystemType) (err error) {
	p.FormatPartitionPaths = append(p.FormatPartitionPaths, partitionPath)
	p.FormatFsTypes = append(p.FormatFsTypes, fsType)
	return
}
