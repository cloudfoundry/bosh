package models

type Job struct {
	Name        string
	Version     string
	Sha1        string
	BlobstoreId string
}

func (s Job) BundleName() string {
	return s.Name
}

func (s Job) BundleVersion() string {
	return s.Version
}
