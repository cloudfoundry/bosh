package fakes

import (
	bc "bosh/agent/applier/bundlecollection"
	boshsys "bosh/system"
	"errors"
)

type FakeBundleCollection struct {
	installedBundles []bc.BundleDefinition
	enabledBundles   []bc.BundleDefinition

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

func (s *FakeBundleCollection) Install(bundle bc.BundleDefinition) (boshsys.FileSystem, string, error) {
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

func (s *FakeBundleCollection) IsInstalled(bundle bc.BundleDefinition) bool {
	return s.checkExists(s.installedBundles, bundle)
}

func (s *FakeBundleCollection) GetDir(bundle bc.BundleDefinition) (fs boshsys.FileSystem, path string, err error) {
	fs = s.GetDirFs
	path = s.GetDirPath
	err = s.GetDirError
	return
}

func (s *FakeBundleCollection) Enable(bundle bc.BundleDefinition) error {
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

func (s *FakeBundleCollection) IsEnabled(bundle bc.BundleDefinition) bool {
	return s.checkExists(s.enabledBundles, bundle)
}

func (s *FakeBundleCollection) checkBundle(bundle bc.BundleDefinition) error {
	if len(bundle.BundleName()) == 0 {
		return errors.New("missing bundle name")
	}
	if len(bundle.BundleVersion()) == 0 {
		return errors.New("missing bundle version")
	}
	return nil
}

func (s *FakeBundleCollection) checkExists(collection []bc.BundleDefinition, bundle bc.BundleDefinition) bool {
	for _, b := range collection {
		if b.BundleName() == bundle.BundleName() {
			if b.BundleVersion() == bundle.BundleVersion() {
				return true
			}
		}
	}
	return false
}
