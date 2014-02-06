package fakes

import (
	bc "bosh/agent/applier/bundlecollection"
	"errors"
)

type FakeBundleCollection struct {
	bundles map[BundleKey]*FakeBundle
}

type BundleKey struct {
	Name    string
	Version string
}

func NewBundleKey(definition bc.BundleDefinition) (key BundleKey) {
	key = BundleKey{
		Name:    definition.BundleName(),
		Version: definition.BundleVersion(),
	}
	return
}

func NewFakeBundleCollection() *FakeBundleCollection {
	return &FakeBundleCollection{
		bundles: map[BundleKey]*FakeBundle{},
	}
}

func (s *FakeBundleCollection) Get(definition bc.BundleDefinition) (bundle bc.Bundle, err error) {
	if len(definition.BundleName()) == 0 {
		err = errors.New("missing bundle name")
		return
	}
	if len(definition.BundleVersion()) == 0 {
		err = errors.New("missing bundle version")
		return
	}

	bundle = s.FakeGet(definition)

	return
}

func (s *FakeBundleCollection) FakeGet(definition bc.BundleDefinition) (bundle *FakeBundle) {
	key := NewBundleKey(definition)
	bundle, found := s.bundles[key]
	if !found {
		bundle = NewFakeBundle()
		s.bundles[key] = bundle
	}

	return
}
