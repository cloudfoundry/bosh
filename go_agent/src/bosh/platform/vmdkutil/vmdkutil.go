package vmdkutil

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"

	boshvmdk "bosh/platform/vmdk"
	"os"
	"path/filepath"
)

type concreteVmdkUtil struct {
	settingsMountPath string
	fs                boshsys.FileSystem
	vmdk              boshvmdk.Vmdk
}

func NewVmdkUtil(settingsMountPath string, fs boshsys.FileSystem, vmdk boshvmdk.Vmdk) (util VmdkUtil) {
	util = concreteVmdkUtil{
		settingsMountPath: settingsMountPath,
		fs:                fs,
		vmdk:              vmdk,
	}
	return
}

func (util concreteVmdkUtil) GetFileContents(fileName string) (contents []byte, err error) {
	err = util.fs.MkdirAll(util.settingsMountPath, os.FileMode(0700))
	if err != nil {
		err = bosherr.WrapError(err, "Creating VMDK mount point")
		return
	}

	err = util.vmdk.Mount(util.settingsMountPath)
	if err != nil {
		err = bosherr.WrapError(err, "Mounting VMDK")
		return
	}

	settingsPath := filepath.Join(util.settingsMountPath, fileName)
	stringContents, err := util.fs.ReadFile(settingsPath)
	if err != nil {
		err = bosherr.WrapError(err, "Reading from VMDK")
		return
	}

	err = util.vmdk.Unmount()
	if err != nil {
		err = bosherr.WrapError(err, "Unmounting VMDK")
		return
	}

	util.fs.RemoveAll(util.settingsMountPath)
	contents = []byte(stringContents)

	return
}
