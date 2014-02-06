package bundlecollection

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"os"
	"path/filepath"
)

type FileBundle struct {
	installPath string
	enablePath  string
	fs          boshsys.FileSystem
}

func NewFileBundle(installPath, enablePath string, fs boshsys.FileSystem) FileBundle {
	return FileBundle{
		installPath: installPath,
		enablePath:  enablePath,
		fs:          fs,
	}
}

func (self FileBundle) Install() (fs boshsys.FileSystem, path string, err error) {
	path = self.installPath
	err = self.fs.MkdirAll(path, os.FileMode(0755))
	if err != nil {
		err = bosherr.WrapError(err, "failed to create install dir")
		return
	}

	fs = self.fs
	return
}

func (self FileBundle) GetInstallPath() (fs boshsys.FileSystem, path string, err error) {
	path = self.installPath
	if !self.fs.FileExists(path) {
		err = bosherr.New("install dir does not exist")
		return
	}

	fs = self.fs
	return
}

func (self FileBundle) Enable() (err error) {
	installPath := self.installPath
	if !self.fs.FileExists(installPath) {
		err = bosherr.New("bundle must be installed")
		return
	}

	enablePath := self.enablePath
	err = self.fs.MkdirAll(filepath.Dir(enablePath), os.FileMode(0755))
	if err != nil {
		err = bosherr.WrapError(err, "failed to create enable dir")
		return
	}

	err = self.fs.Symlink(installPath, enablePath)
	if err != nil {
		err = bosherr.WrapError(err, "failed to enable")
		return
	}

	return
}
