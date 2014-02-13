package bundlecollection

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"path/filepath"
)

type FileBundleCollection struct {
	name        string
	installPath string
	enablePath  string
	fs          boshsys.FileSystem
}

func NewFileBundleCollection(installPath, enablePath, name string, fs boshsys.FileSystem) FileBundleCollection {
	return FileBundleCollection{
		name:        name,
		installPath: installPath,
		enablePath:  enablePath,
		fs:          fs,
	}
}

func (self FileBundleCollection) Get(definition BundleDefinition) (bundle Bundle, err error) {
	if len(definition.BundleName()) == 0 {
		err = bosherr.New("missing bundle name")
		return
	}
	if len(definition.BundleVersion()) == 0 {
		err = bosherr.New("missing bundle version")
		return
	}

	installPath := filepath.Join(self.installPath, self.name, definition.BundleName(), definition.BundleVersion())
	enablePath := filepath.Join(self.enablePath, self.name, definition.BundleName())

	bundle = NewFileBundle(installPath, enablePath, self.fs)
	return
}
