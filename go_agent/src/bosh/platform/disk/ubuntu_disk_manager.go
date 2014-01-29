package disk

import (
	boshlog "bosh/logger"
	boshsys "bosh/system"
)

type ubuntuDiskManager struct {
	partitioner Partitioner
	formatter   Formatter
	mounter     Mounter
	finder      Finder
}

func NewUbuntuDiskManager(logger boshlog.Logger, runner boshsys.CmdRunner, fs boshsys.FileSystem, finder Finder) (manager Manager) {
	return ubuntuDiskManager{
		partitioner: newSfdiskPartitioner(logger, runner),
		formatter:   newLinuxFormatter(runner, fs),
		mounter:     newLinuxMounter(runner, fs),
		finder:      finder,
	}
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

func (m ubuntuDiskManager) GetFinder() Finder {
	return m.finder
}
