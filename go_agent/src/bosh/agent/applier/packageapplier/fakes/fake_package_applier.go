package fakes

import (
	models "bosh/agent/applier/models"
)

type FakePackageApplier struct {
	AppliedPackages []models.Package
	ApplyError      error

	KeepOnlyPackages []models.Package
	KeepOnlyErr      error
}

func NewFakePackageApplier() *FakePackageApplier {
	return &FakePackageApplier{
		AppliedPackages: []models.Package{},
	}
}

func (s *FakePackageApplier) Apply(pkg models.Package) error {
	s.AppliedPackages = append(s.AppliedPackages, pkg)
	return s.ApplyError
}

func (s *FakePackageApplier) KeepOnly(pkgs []models.Package) error {
	s.KeepOnlyPackages = pkgs
	return s.KeepOnlyErr
}
