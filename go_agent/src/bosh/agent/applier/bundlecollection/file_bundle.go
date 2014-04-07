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

func (b FileBundle) Install() (boshsys.FileSystem, string, error) {
	b.logger.Debug(fileBundleLogTag, "Installing %v", b)

	path := b.installPath

	err := b.fs.MkdirAll(path, os.FileMode(0755))
	if err != nil {
		return nil, "", bosherr.WrapError(err, "Creating install dir")
	}

	return b.fs, path, nil
}

func (b FileBundle) GetInstallPath() (boshsys.FileSystem, string, error) {
	path := b.installPath
	if !b.fs.FileExists(path) {
		return nil, "", bosherr.New("install dir does not exist")
	}

	return b.fs, path, nil
}

func (b FileBundle) Enable() (boshsys.FileSystem, string, error) {
	b.logger.Debug(fileBundleLogTag, "Enabling %v", b)

	if !b.fs.FileExists(b.installPath) {
		return nil, "", bosherr.New("bundle must be installed")
	}

	err := b.fs.MkdirAll(filepath.Dir(b.enablePath), os.FileMode(0755))
	if err != nil {
		return nil, "", bosherr.WrapError(err, "failed to create enable dir")
	}

	err = b.fs.Symlink(b.installPath, b.enablePath)
	if err != nil {
		return nil, "", bosherr.WrapError(err, "failed to enable")
	}

	return b.fs, b.enablePath, nil
}

func (b FileBundle) Disable() error {
	b.logger.Debug(fileBundleLogTag, "Disabling %v", b)

	target, err := b.fs.ReadLink(b.enablePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return bosherr.WrapError(err, "Reading symlink")
	}

	if target == b.installPath {
		return b.fs.RemoveAll(b.enablePath)
	}

	return nil
}

func (b FileBundle) Uninstall() error {
	b.logger.Debug(fileBundleLogTag, "Uninstalling %v", b)
	return b.fs.RemoveAll(b.installPath)
}
