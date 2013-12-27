package bundlecollection

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"os"
	"path/filepath"
)

type FileBundleCollection struct {
	name        string
	installPath string
	enablePath  string
	fs          boshsys.FileSystem
}

func NewFileBundleCollection(installPath, enablePath, name string, fs boshsys.FileSystem) *FileBundleCollection {
	return &FileBundleCollection{
		name:        name,
		installPath: installPath,
		enablePath:  enablePath,
		fs:          fs,
	}
}

// Installed into {{ installPath }}/{{ name }}/{{ bundle.BundleName }}/{{ bundle.BundleVersion }}
func (s *FileBundleCollection) Install(bundle Bundle) (fs boshsys.FileSystem, path string, err error) {
	err = s.checkBundle(bundle)
	if err != nil {
		return
	}

	path = s.buildInstallPath(bundle)
	err = s.fs.MkdirAll(path, os.FileMode(0755))
	if err != nil {
		err = bosherr.WrapError(err, "failed to create install dir")
		return
	}

	fs = s.fs
	return
}

func (s *FileBundleCollection) GetDir(bundle Bundle) (fs boshsys.FileSystem, path string, err error) {
	err = s.checkBundle(bundle)
	if err != nil {
		return
	}

	path = s.buildInstallPath(bundle)
	if !s.fs.FileExists(path) {
		err = bosherr.New("install dir does not exist")
		return
	}

	fs = s.fs
	return
}

// Symlinked from {{ enablePath }}/{{ name }}/{{ bundle.BundleName }} to installed path
func (s *FileBundleCollection) Enable(bundle Bundle) (err error) {
	err = s.checkBundle(bundle)
	if err != nil {
		return
	}

	installPath := s.buildInstallPath(bundle)
	if !s.fs.FileExists(installPath) {
		err = bosherr.New("bundle must be installed")
		return
	}

	enablePath := s.buildEnablePath(bundle)
	err = s.fs.MkdirAll(filepath.Dir(enablePath), os.FileMode(0755))
	if err != nil {
		err = bosherr.WrapError(err, "failed to create enable dir")
		return
	}

	err = s.fs.Symlink(installPath, enablePath)
	if err != nil {
		err = bosherr.WrapError(err, "failed to enable")
		return
	}

	return
}

func (s *FileBundleCollection) checkBundle(bundle Bundle) (err error) {
	if len(bundle.BundleName()) == 0 {
		err = bosherr.New("missing bundle name")
		return
	}
	if len(bundle.BundleVersion()) == 0 {
		err = bosherr.New("missing bundle version")
		return
	}
	return
}

func (s *FileBundleCollection) buildInstallPath(bundle Bundle) string {
	return filepath.Join(s.installPath, s.name, bundle.BundleName(), bundle.BundleVersion())
}

func (s *FileBundleCollection) buildEnablePath(bundle Bundle) string {
	return filepath.Join(s.enablePath, s.name, bundle.BundleName())
}
