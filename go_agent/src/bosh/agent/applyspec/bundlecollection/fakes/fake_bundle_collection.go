package fakes

import (
	bc "bosh/agent/applyspec/bundlecollection"
	"errors"
)

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
	err := s.checkBundle(bundle)
	if err != nil {
		return "", err
	}

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
	err := s.checkBundle(bundle)
	if err != nil {
		return err
	}

	if s.EnableError != nil {
		return s.EnableError
	}
	s.enabledBundles = append(s.enabledBundles, bundle)
	return nil
}

func (s *FakeBundleCollection) IsEnabled(bundle bc.Bundle) bool {
	return s.checkExists(s.enabledBundles, bundle)
}

func (s *FakeBundleCollection) checkBundle(bundle bc.Bundle) error {
	if len(bundle.BundleName()) == 0 {
		return errors.New("missing bundle name")
	}
	if len(bundle.BundleVersion()) == 0 {
		return errors.New("missing bundle version")
	}
	return nil
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
