package fakes

import (
	bc "bosh/agent/applier/bundlecollection"
	boshsys "bosh/system"
	"errors"
)

type FakeBundleCollection struct {
	installedBundles []bc.Bundle
	enabledBundles   []bc.Bundle

	InstallFs    boshsys.FileSystem
	InstallPath  string
	InstallError error

	GetDirPath  string
	GetDirFs    boshsys.FileSystem
	GetDirError error

	EnableError error
}

func NewFakeBundleCollection() *FakeBundleCollection {
	return &FakeBundleCollection{}
}

func (s *FakeBundleCollection) Install(bundle bc.Bundle) (boshsys.FileSystem, string, error) {
	err := s.checkBundle(bundle)
	if err != nil {
		return nil, "", err
	}

	if s.InstallError != nil {
		return nil, "", s.InstallError
	}
	s.installedBundles = append(s.installedBundles, bundle)
	return s.InstallFs, s.InstallPath, nil
}

func (s *FakeBundleCollection) IsInstalled(bundle bc.Bundle) bool {
	return s.checkExists(s.installedBundles, bundle)
}

func (s *FakeBundleCollection) GetDir(bundle bc.Bundle) (fs boshsys.FileSystem, path string, err error) {
	fs = s.GetDirFs
	path = s.GetDirPath
	err = s.GetDirError
	return
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
