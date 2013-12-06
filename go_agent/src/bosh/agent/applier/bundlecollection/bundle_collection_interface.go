package bundlecollection

// e.g. Job, Package
type Bundle interface {
	BundleName() string
	BundleVersion() string
}

// BundleCollection is responsible for managing multiple bundles
// where bundles can be installed and then enabled.
// e.g. Used to manage currently installed/enabled jobs and packages.
type BundleCollection interface {
	Install(bundle Bundle) (string, error)
	Enable(bundle Bundle) error
}
