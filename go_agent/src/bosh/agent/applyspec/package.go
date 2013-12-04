package applyspec

type Package struct {
	Name        string
	Version     string
	Sha1        string
	BlobstoreId string
}

func (s Package) BundleName() string {
	return s.Name
}

func (s Package) BundleVersion() string {
	return s.Version
}
