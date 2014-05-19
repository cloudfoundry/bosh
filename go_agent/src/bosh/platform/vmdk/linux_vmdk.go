package vmdk

import (
	"regexp"
	"strings"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshsys "bosh/system"
)

const vmdkLogTag = "vmdk"

type LinuxVmdk struct {
	runner boshsys.CmdRunner
	logger boshlog.Logger
}

func NewLinuxVmdk(runner boshsys.CmdRunner, logger boshlog.Logger) (vmdk LinuxVmdk) {
	vmdk = LinuxVmdk{
		runner: runner,
		logger: logger,
	}
	return
}

func (vmdk LinuxVmdk) getDevicePath() (devicePath string, err error) {
	cmdOut, _, _, err := vmdk.runner.RunCommand("blkid")
	if err != nil {
		vmdk.logger.Error(vmdkLogTag, "Error of command blkid: %s", err.Error())
		return
	}

	regex, _ := regexp.Compile("(\\/dev\\/sd\\w+):")
	for _, line := range strings.Split(cmdOut, "\n") {
		if strings.Contains(line, "LABEL=\"CDROM\" TYPE=\"iso9660\"") {
			matched_line := regex.FindString(line)
			devicePath = matched_line[0 : len(matched_line)-1]
			return
		}
	}

	vmdk.logger.Error(vmdkLogTag, "Unable to find disk of LABEL=\"CDROM\" TYPE=\"iso9660\"")
	err = bosherr.WrapError(err, "Getting VMDK Device Path: Unable to find disk of LABEL=\"CDROM\" TYPE=\"iso9660\"")
	return
}

func (vmdk LinuxVmdk) Mount(mountPath string) (err error) {
	devicePath, err := vmdk.getDevicePath()
	if err != nil {
		return
	}

	_, stderr, _, err := vmdk.runner.RunCommand("mount", devicePath, mountPath)
	if err != nil {
		err = bosherr.WrapError(err, "Mounting VMDK: %s", stderr)
	}
	return
}

func (vmdk LinuxVmdk) Unmount() (err error) {
	devicePath, err := vmdk.getDevicePath()
	if err != nil {
		return
	}

	_, stderr, _, err := vmdk.runner.RunCommand("umount", devicePath)
	if err != nil {
		err = bosherr.WrapError(err, "Unmounting VMDK: %s", stderr)
	}
	return
}
