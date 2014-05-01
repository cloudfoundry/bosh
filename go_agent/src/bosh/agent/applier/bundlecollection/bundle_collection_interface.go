package bundlecollection

import (
	boshsys "bosh/system"
)

// BundleDefinition uniquely identifies an asset within a BundleCollection (e.g. Job, Package)
type BundleDefinition interface {
	BundleName() string
	BundleVersion() string
}

type BundleCollection interface {
	Get(defintion BundleDefinition) (bundle Bundle, err error)
	List() ([]Bundle, error)
}

type Bundle interface {
	Install(sourcePath string) (fs boshsys.FileSystem, path string, err error)
	InstallWithoutContents() (fs boshsys.FileSystem, path string, err error)
	Uninstall() (err error)

	IsInstalled() (bool, error)
	GetInstallPath() (fs boshsys.FileSystem, path string, err error)

	Enable() (fs boshsys.FileSystem, path string, err error)
	Disable() (err error)
}
