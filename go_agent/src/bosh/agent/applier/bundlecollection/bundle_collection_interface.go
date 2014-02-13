package bundlecollection

import boshsys "bosh/system"

// e.g. Job, Package
type BundleDefinition interface {
	BundleName() string
	BundleVersion() string
}

type BundleCollection interface {
	Get(defintion BundleDefinition) (bundle Bundle, err error)
}

type Bundle interface {
	Install() (fs boshsys.FileSystem, path string, err error)

	GetInstallPath() (fs boshsys.FileSystem, path string, err error)

	Enable() (fs boshsys.FileSystem, path string, err error)

	Disable() (err error)

	Uninstall() (err error)
}
