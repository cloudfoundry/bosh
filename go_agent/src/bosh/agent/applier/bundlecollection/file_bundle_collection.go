package bundlecollection

import (
	"path/filepath"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshsys "bosh/system"
)

const fileBundleCollectionLogTag = "FileBundleCollection"

type fileBundleDefinition struct {
	name    string
	version string
}

func newFileBundleDefinition(installPath string) fileBundleDefinition {
	cleanInstallPath := filepath.Clean(installPath) // no trailing slash

	// If the path is empty, Base returns ".".
	// If the path consists entirely of separators, Base returns a single separator.

	name := filepath.Base(filepath.Dir(cleanInstallPath))
	if name == "." || name == string(filepath.Separator) {
		name = ""
	}

	version := filepath.Base(cleanInstallPath)
	if version == "." || version == string(filepath.Separator) {
		version = ""
	}

	return fileBundleDefinition{name: name, version: version}
}

func (bd fileBundleDefinition) BundleName() string    { return bd.name }
func (bd fileBundleDefinition) BundleVersion() string { return bd.version }

type FileBundleCollection struct {
	name        string
	installPath string
	enablePath  string
	fs          boshsys.FileSystem
	logger      boshlog.Logger
}

func NewFileBundleCollection(
	installPath, enablePath, name string,
	fs boshsys.FileSystem,
	logger boshlog.Logger,
) FileBundleCollection {
	return FileBundleCollection{
		name:        name,
		installPath: installPath,
		enablePath:  enablePath,
		fs:          fs,
		logger:      logger,
	}
}

func (bc FileBundleCollection) Get(definition BundleDefinition) (Bundle, error) {
	if len(definition.BundleName()) == 0 {
		return nil, bosherr.New("Missing bundle name")
	}

	if len(definition.BundleVersion()) == 0 {
		return nil, bosherr.New("Missing bundle version")
	}

	installPath := filepath.Join(bc.installPath, bc.name, definition.BundleName(), definition.BundleVersion())
	enablePath := filepath.Join(bc.enablePath, bc.name, definition.BundleName())
	return NewFileBundle(installPath, enablePath, bc.fs, bc.logger), nil
}

func (bc FileBundleCollection) List() ([]Bundle, error) {
	var bundles []Bundle

	bundleInstallPaths, err := bc.fs.Glob(filepath.Join(bc.installPath, bc.name, "*", "*"))
	if err != nil {
		return bundles, bosherr.WrapError(err, "Globbing bundles")
	}

	for _, path := range bundleInstallPaths {
		bundle, err := bc.Get(newFileBundleDefinition(path))
		if err != nil {
			return bundles, bosherr.WrapError(err, "Getting bundle")
		}

		bundles = append(bundles, bundle)
	}

	bc.logger.Debug(fileBundleCollectionLogTag, "Collection contains bundles %v", bundles)

	return bundles, nil
}
