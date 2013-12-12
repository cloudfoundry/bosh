package bundlecollection

import boshsys "bosh/system"

// e.g. Job, Package
type Bundle interface {
	BundleName() string
	BundleVersion() string
}

// BundleCollection is responsible for managing multiple bundles
// where bundles can be installed and then enabled.
// e.g. Used to manage currently installed/enabled jobs and packages.
type BundleCollection interface {

	// Instead of returning filesys/path it would be nice
	// to return a Directory object that would really represent
	// some location (s3 bucket, fs, etc.)
	Install(bundle Bundle) (boshsys.FileSystem, string, error)

	GetDir(bundle Bundle) (fs boshsys.FileSystem, path string, err error)

	Enable(bundle Bundle) error
}
