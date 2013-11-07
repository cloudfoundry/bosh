package disk

import boshsys "bosh/system"

type ubuntuDiskManager struct {
	partitioner Partitioner
	formatter   Formatter
	mounter     Mounter
}

func NewUbuntuDiskManager(runner boshsys.CmdRunner) (manager ubuntuDiskManager) {
	manager.partitioner = NewSfdiskPartitioner(runner)
	manager.formatter = NewLinuxFormatter(runner)
	manager.mounter = NewLinuxMounter(runner)
	return
}

func (m ubuntuDiskManager) GetPartitioner() Partitioner {
	return m.partitioner
}

func (m ubuntuDiskManager) GetFormatter() Formatter {
	return m.formatter
}

func (m ubuntuDiskManager) GetMounter() Mounter {
	return m.mounter
}
