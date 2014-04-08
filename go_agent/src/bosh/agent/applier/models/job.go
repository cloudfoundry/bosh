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
	// Job template is not unique per version because
	// Source contains files with interpolated values
	// which might be different across job versions.
	return s.Version + "-" + s.Source.Sha1
}
