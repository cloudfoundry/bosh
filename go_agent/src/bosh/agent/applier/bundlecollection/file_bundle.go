package bundlecollection

import (
	"os"
	"path/filepath"

	bosherr "bosh/errors"
	boshsys "bosh/system"
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

func (self FileBundle) Install() (boshsys.FileSystem, string, error) {
	path := self.installPath

	err := self.fs.MkdirAll(path, os.FileMode(0755))
	if err != nil {
		return self.fs, path, bosherr.WrapError(err, "Creating install dir")
	}

	return self.fs, path, nil
}

func (self FileBundle) GetInstallPath() (boshsys.FileSystem, string, error) {
	path := self.installPath
	if !self.fs.FileExists(path) {
		return self.fs, path, bosherr.New("install dir does not exist")
	}

	return self.fs, path, nil
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
