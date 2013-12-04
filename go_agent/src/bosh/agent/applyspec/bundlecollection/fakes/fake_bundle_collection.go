package fakes

import bc "bosh/agent/applyspec/bundlecollection"

type FakeBundleCollection struct {
	installedBundles []bc.Bundle
	enabledBundles   []bc.Bundle

	InstallError error
	EnableError  error
}

func NewFakeBundleCollection() *FakeBundleCollection {
	return &FakeBundleCollection{
		installedBundles: make([]bc.Bundle, 0),
		enabledBundles:   make([]bc.Bundle, 0),
	}
}

func (s *FakeBundleCollection) Install(bundle bc.Bundle) (string, error) {
	if s.InstallError != nil {
		return "", s.InstallError
	}
	s.installedBundles = append(s.installedBundles, bundle)
	return "some-path", nil
}

func (s *FakeBundleCollection) IsInstalled(bundle bc.Bundle) bool {
	return s.checkExists(s.installedBundles, bundle)
}

func (s *FakeBundleCollection) Enable(bundle bc.Bundle) error {
	if s.EnableError != nil {
		return s.EnableError
	}
	s.enabledBundles = append(s.enabledBundles, bundle)
	return nil
}

func (s *FakeBundleCollection) IsEnabled(bundle bc.Bundle) bool {
	return s.checkExists(s.enabledBundles, bundle)
}

func (s *FakeBundleCollection) checkExists(collection []bc.Bundle, bundle bc.Bundle) bool {
	for _, b := range collection {
		if b.BundleName() == bundle.BundleName() {
			if b.BundleVersion() == bundle.BundleVersion() {
				return true
			}
		}
	}
	return false
}
