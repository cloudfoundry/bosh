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

func (self FileBundle) Enable() (fs boshsys.FileSystem, path string, err error) {
	if !self.fs.FileExists(self.installPath) {
		err = bosherr.New("bundle must be installed")
		return
	}

	err = self.fs.MkdirAll(filepath.Dir(self.enablePath), os.FileMode(0755))
	if err != nil {
		err = bosherr.WrapError(err, "failed to create enable dir")
		return
	}

	err = self.fs.Symlink(self.installPath, self.enablePath)
	if err != nil {
		err = bosherr.WrapError(err, "failed to enable")
		return
	}

	fs = self.fs
	path = self.enablePath

	return
}

func (self FileBundle) Disable() (err error) {
	target, err := self.fs.ReadLink(self.enablePath)
	if err != nil {
		if os.IsNotExist(err) {
			err = nil
			return
		}
		err = bosherr.WrapError(err, "Reading symlink")
		return
	}

	if target == self.installPath {
		self.fs.RemoveAll(self.enablePath)
	}
	return
}

func (self FileBundle) Uninstall() (err error) {
	err = self.fs.RemoveAll(self.installPath)
	return
}
