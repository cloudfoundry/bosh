package fakes

import (
	boshdisk "bosh/platform/disk"
)

type FakeDiskManager struct {
	FakePartitioner *FakePartitioner
	FakeFormatter   *FakeFormatter
	FakeMounter     *FakeMounter
}

func NewFakeDiskManager() (manager *FakeDiskManager) {
	manager = &FakeDiskManager{}
	manager.FakePartitioner = &FakePartitioner{}
	manager.FakeFormatter = &FakeFormatter{}
	manager.FakeMounter = &FakeMounter{}
	return
}

func (m FakeDiskManager) GetPartitioner() boshdisk.Partitioner {
	return m.FakePartitioner
}

func (m FakeDiskManager) GetFormatter() boshdisk.Formatter {
	return m.FakeFormatter
}

func (m FakeDiskManager) GetMounter() boshdisk.Mounter {
	return m.FakeMounter
}
