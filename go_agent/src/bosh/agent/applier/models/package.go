package models

type Package struct {
	Name    string
	Version string
	Source  Source
}

func (s Package) BundleName() string {
	return s.Name
}

func (s Package) BundleVersion() string {
	return s.Version + "-" + s.Source.Sha1
}
