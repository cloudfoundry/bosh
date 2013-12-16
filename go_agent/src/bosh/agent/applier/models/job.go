package models

type Job struct {
	Name    string
	Version string
	Source  Source
}

func (s Job) BundleName() string {
	return s.Name
}

func (s Job) BundleVersion() string {
	return s.Version
}
