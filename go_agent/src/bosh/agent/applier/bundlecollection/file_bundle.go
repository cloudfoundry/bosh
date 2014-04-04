package bundlecollection

import (
	"os"
	"path/filepath"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshsys "bosh/system"
)

const fileBundleLogTag = "FileBundle"

type FileBundle struct {
	installPath string
	enablePath  string
	fs          boshsys.FileSystem
	logger      boshlog.Logger
}

func NewFileBundle(installPath, enablePath string, fs boshsys.FileSystem, logger boshlog.Logger) FileBundle {
	return FileBundle{
		installPath: installPath,
		enablePath:  enablePath,
		fs:          fs,
		logger:      logger,
	}
}

func (self FileBundle) Install() (boshsys.FileSystem, string, error) {
	self.logger.Debug(fileBundleLogTag, "Installing %v", self)

	path := self.installPath

	err := self.fs.MkdirAll(path, os.FileMode(0755))
	if err != nil {
		return nil, "", bosherr.WrapError(err, "Creating install dir")
	}

	return self.fs, path, nil
}

func (self FileBundle) GetInstallPath() (boshsys.FileSystem, string, error) {
	path := self.installPath
	if !self.fs.FileExists(path) {
		return nil, "", bosherr.New("install dir does not exist")
	}

	return self.fs, path, nil
}

func (self FileBundle) Enable() (boshsys.FileSystem, string, error) {
	self.logger.Debug(fileBundleLogTag, "Enabling %v", self)

	if !self.fs.FileExists(self.installPath) {
		return nil, "", bosherr.New("bundle must be installed")
	}

	err := self.fs.MkdirAll(filepath.Dir(self.enablePath), os.FileMode(0755))
	if err != nil {
		return nil, "", bosherr.WrapError(err, "failed to create enable dir")
	}

	err = self.fs.Symlink(self.installPath, self.enablePath)
	if err != nil {
		return nil, "", bosherr.WrapError(err, "failed to enable")
	}

	return self.fs, self.enablePath, nil
}

func (self FileBundle) Disable() error {
	self.logger.Debug(fileBundleLogTag, "Disabling %v", self)

	target, err := self.fs.ReadLink(self.enablePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return bosherr.WrapError(err, "Reading symlink")
	}

	if target == self.installPath {
		self.fs.RemoveAll(self.enablePath)
	}

	return nil
}

func (self FileBundle) Uninstall() error {
	self.logger.Debug(fileBundleLogTag, "Uninstalling %v", self)
	return self.fs.RemoveAll(self.installPath)
}
