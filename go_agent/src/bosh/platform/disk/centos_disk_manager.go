package disk

import (
	boshlog "bosh/logger"
	boshsys "bosh/system"
	"time"
)

type centosDiskManager struct {
	partitioner Partitioner
	formatter   Formatter
	mounter     Mounter
}

func NewCentosDiskManager(logger boshlog.Logger, runner boshsys.CmdRunner, fs boshsys.FileSystem) (manager Manager) {
	return centosDiskManager{
		partitioner: NewSfdiskPartitioner(logger, runner),
		formatter:   NewLinuxFormatter(runner, fs),
		mounter:     NewLinuxMounter(runner, fs, 1*time.Second),
	}
}

func (m centosDiskManager) GetPartitioner() Partitioner {
	return m.partitioner
}

func (m centosDiskManager) GetFormatter() Formatter {
	return m.formatter
}

func (m centosDiskManager) GetMounter() Mounter {
	return m.mounter
}
