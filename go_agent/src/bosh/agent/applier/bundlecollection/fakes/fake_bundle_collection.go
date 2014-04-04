package fakes

import (
	"errors"

	bc "bosh/agent/applier/bundlecollection"
)

type FakeBundleCollection struct {
	bundles map[BundleKey]*FakeBundle

	ListBundles []bc.Bundle
	ListErr     error
	GetErr      error
}

type BundleKey struct {
	Name    string
	Version string
}

func NewBundleKey(definition bc.BundleDefinition) BundleKey {
	return BundleKey{
		Name:    definition.BundleName(),
		Version: definition.BundleVersion(),
	}
}

func NewFakeBundleCollection() *FakeBundleCollection {
	return &FakeBundleCollection{
		bundles: map[BundleKey]*FakeBundle{},
	}
}

func (s *FakeBundleCollection) Get(definition bc.BundleDefinition) (bc.Bundle, error) {
	if len(definition.BundleName()) == 0 {
		return nil, errors.New("missing bundle name")
	}

	if len(definition.BundleVersion()) == 0 {
		return nil, errors.New("missing bundle version")
	}

	return s.FakeGet(definition), s.GetErr
}

func (s *FakeBundleCollection) FakeGet(definition bc.BundleDefinition) *FakeBundle {
	key := NewBundleKey(definition)

	bundle, found := s.bundles[key]
	if !found {
		bundle = NewFakeBundle()
		s.bundles[key] = bundle
	}

	return bundle
}

func (s *FakeBundleCollection) List() ([]bc.Bundle, error) {
	return s.ListBundles, s.ListErr
}
