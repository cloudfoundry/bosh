package disk

import (
	boshlog "bosh/logger"
	boshsys "bosh/system"
	"time"
)

type ubuntuDiskManager struct {
	partitioner Partitioner
	formatter   Formatter
	mounter     Mounter
}

func NewUbuntuDiskManager(logger boshlog.Logger, runner boshsys.CmdRunner, fs boshsys.FileSystem) (manager Manager) {
	return ubuntuDiskManager{
		partitioner: NewSfdiskPartitioner(logger, runner),
		formatter:   NewLinuxFormatter(runner, fs),
		mounter:     NewLinuxMounter(runner, fs, 1*time.Second),
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
