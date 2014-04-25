package disk

import (
	"time"

	boshlog "bosh/logger"
	boshsys "bosh/system"
)

type linuxDiskManager struct {
	partitioner Partitioner
	formatter   Formatter
	mounter     Mounter
}

func NewLinuxDiskManager(
	logger boshlog.Logger,
	runner boshsys.CmdRunner,
	fs boshsys.FileSystem,
	bindMount bool,
) (manager Manager) {
	var mounter Mounter

	mountsSearcher := NewProcMountsSearcher(fs)

	mounter = NewLinuxMounter(runner, fs, mountsSearcher, 1*time.Second)
	if bindMount {
		mounter = NewLinuxBindMounter(mounter)
	}

	return linuxDiskManager{
		partitioner: NewSfdiskPartitioner(logger, runner),
		formatter:   NewLinuxFormatter(runner, fs),
		mounter:     mounter,
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
