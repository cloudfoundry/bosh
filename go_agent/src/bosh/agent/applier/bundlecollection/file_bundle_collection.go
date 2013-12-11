package bundlecollection

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"os"
	"path/filepath"
)

type FileBundleCollection struct {
	name string
	path string
	fs   boshsys.FileSystem
}

func NewFileBundleCollection(name, path string, fs boshsys.FileSystem) *FileBundleCollection {
	return &FileBundleCollection{
		name: name,
		path: path,
		fs:   fs,
	}
}

// Installed into {{ path }}/data/{{ name }}/{{ bundle.BundleName }}/{{ bundle.BundleVersion }}
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

// Symlinked from {{ path }}/{{ name }}/{{ bundle.BundleName }} to installed path
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
	return filepath.Join(s.path, "data", s.name, bundle.BundleName(), bundle.BundleVersion())
}

func (s *FileBundleCollection) buildEnablePath(bundle Bundle) string {
	return filepath.Join(s.path, s.name, bundle.BundleName())
}
