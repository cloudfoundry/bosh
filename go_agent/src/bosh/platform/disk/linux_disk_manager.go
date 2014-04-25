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
	var mountsSearcher MountsSearcher

	// By default we want to use most reliable source of
	// mount information which is /proc/mounts
	mountsSearcher = NewProcMountsSearcher(fs)

	// Bind mounting in a container (warden) will not allow
	// reliably determine which device backs a mount point,
	// so we use less reliable source of mount information:
	// the mount command which returns information from /etc/mtab.
	if bindMount {
		mountsSearcher = NewCmdMountsSearcher(runner)
	}

	mounter = NewLinuxMounter(runner, mountsSearcher, 1*time.Second)

	if bindMount {
		mounter = NewLinuxBindMounter(mounter)
	}

	return linuxDiskManager{
		partitioner: NewSfdiskPartitioner(logger, runner),
		formatter:   NewLinuxFormatter(runner, fs),
		mounter:     mounter,
	}
}

func (m linuxDiskManager) GetPartitioner() Partitioner { return m.partitioner }
func (m linuxDiskManager) GetFormatter() Formatter     { return m.formatter }
func (m linuxDiskManager) GetMounter() Mounter         { return m.mounter }
