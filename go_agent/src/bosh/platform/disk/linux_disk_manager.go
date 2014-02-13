package disk

import (
	boshlog "bosh/logger"
	boshsys "bosh/system"
	"time"
)

type linuxDiskManager struct {
	partitioner Partitioner
	formatter   Formatter
	mounter     Mounter
}

func NewLinuxDiskManager(logger boshlog.Logger, runner boshsys.CmdRunner, fs boshsys.FileSystem) (manager Manager) {
	return linuxDiskManager{
		partitioner: NewSfdiskPartitioner(logger, runner),
		formatter:   NewLinuxFormatter(runner, fs),
		mounter:     NewLinuxMounter(runner, fs, 1*time.Second),
	}
}

func (m linuxDiskManager) GetPartitioner() Partitioner {
	return m.partitioner
}

func (m linuxDiskManager) GetFormatter() Formatter {
	return m.formatter
}

func (m linuxDiskManager) GetMounter() Mounter {
	return m.mounter
}
