package disk

import boshsys "bosh/system"

type linuxMounter struct {
	runner boshsys.CmdRunner
}

func NewLinuxMounter(runner boshsys.CmdRunner) (mounter linuxMounter) {
	mounter.runner = runner
	return
}

func (m linuxMounter) Mount(partitionPath, mountPoint string) (err error) {
	_, _, err = m.runner.RunCommand("mount", partitionPath, mountPoint)
	return
}

func (m linuxMounter) SwapOn(partitionPath string) (err error) {
	_, _, err = m.runner.RunCommand("swapon", partitionPath)
	return
}
