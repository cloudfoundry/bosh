package bundlecollection

import boshsys "bosh/system"

// e.g. Job, Package
type BundleDefinition interface {
	BundleName() string
	BundleVersion() string
}

// BundleCollection is responsible for managing multiple bundles
// where bundles can be installed and then enabled.
// e.g. Used to manage currently installed/enabled jobs and packages.
type BundleCollectionOld interface {

	// Instead of returning filesys/path it would be nice
	// to return a Directory object that would really represent
	// some location (s3 bucket, fs, etc.)
	Install(defintion BundleDefinition) (boshsys.FileSystem, string, error)

	GetDir(defintion BundleDefinition) (fs boshsys.FileSystem, path string, err error)

	Enable(defintion BundleDefinition) error
}

type BundleCollection interface {
	Get(defintion BundleDefinition) (bundle Bundle, err error)
}

type Bundle interface {
	Install() (fs boshsys.FileSystem, path string, err error)

	GetInstallPath() (fs boshsys.FileSystem, path string, err error)

	Enable() (fs boshsys.FileSystem, path string, err error)

	Disable() (err error)
}
