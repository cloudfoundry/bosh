package fakes

import models "bosh/agent/applier/models"

type FakePackageApplier struct {
	AppliedPackages []models.Package
	ApplyError      error
}

func NewFakePackageApplier() *FakePackageApplier {
	return &FakePackageApplier{
		AppliedPackages: make([]models.Package, 0),
	}
}

func (s *FakePackageApplier) Apply(pkg models.Package) error {
	if s.ApplyError != nil {
		return s.ApplyError
	}

	s.AppliedPackages = append(s.AppliedPackages, pkg)
	return nil
}
