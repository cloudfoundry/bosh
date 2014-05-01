package bundlecollection

import (
	"os"
	"path/filepath"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshsys "bosh/system"
)

const (
	fileBundleLogTag = "FileBundle"
	installDirsPerms = os.FileMode(0755)
	enableDirPerms   = os.FileMode(0755)
)

type FileBundle struct {
	installPath string
	enablePath  string
	fs          boshsys.FileSystem
	logger      boshlog.Logger
}

func NewFileBundle(
	installPath, enablePath string,
	fs boshsys.FileSystem,
	logger boshlog.Logger,
) FileBundle {
	return FileBundle{
		installPath: installPath,
		enablePath:  enablePath,
		fs:          fs,
		logger:      logger,
	}
}

func (b FileBundle) Install(sourcePath string) (boshsys.FileSystem, string, error) {
	b.logger.Debug(fileBundleLogTag, "Installing %v", b)

	err := b.fs.Chmod(sourcePath, installDirsPerms)
	if err != nil {
		return nil, "", bosherr.WrapError(err, "Settting permissions on source directory")
	}

	err = b.fs.MkdirAll(filepath.Dir(b.installPath), installDirsPerms)
	if err != nil {
		return nil, "", bosherr.WrapError(err, "Creating parent installation directory")
	}

	// Rename MUST be the last possibly-failing operation
	// because IsInstalled() relies on installPath presence.
	err = b.fs.Rename(sourcePath, b.installPath)
	if err != nil {
		return nil, "", bosherr.WrapError(err, "Moving to installation directory")
	}

	return b.fs, b.installPath, nil
}

func (b FileBundle) InstallWithoutContents() (boshsys.FileSystem, string, error) {
	b.logger.Debug(fileBundleLogTag, "Installing without contents %v", b)

	// MkdirAll MUST be the last possibly-failing operation
	// because IsInstalled() relies on installPath presence.
	err := b.fs.MkdirAll(b.installPath, installDirsPerms)
	if err != nil {
		return nil, "", bosherr.WrapError(err, "Creating installation directory")
	}

	return b.fs, b.installPath, nil
}

func (b FileBundle) GetInstallPath() (boshsys.FileSystem, string, error) {
	path := b.installPath
	if !b.fs.FileExists(path) {
		return nil, "", bosherr.New("install dir does not exist")
	}

	return b.fs, path, nil
}

func (b FileBundle) IsInstalled() (bool, error) {
	return b.fs.FileExists(b.installPath), nil
}

func (b FileBundle) Enable() (boshsys.FileSystem, string, error) {
	b.logger.Debug(fileBundleLogTag, "Enabling %v", b)

	if !b.fs.FileExists(b.installPath) {
		return nil, "", bosherr.New("bundle must be installed")
	}

	err := b.fs.MkdirAll(filepath.Dir(b.enablePath), enableDirPerms)
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

	// RemoveAll MUST be the last possibly-failing operation
	// because IsInstalled() relies on installPath presence.
	return b.fs.RemoveAll(b.installPath)
}
