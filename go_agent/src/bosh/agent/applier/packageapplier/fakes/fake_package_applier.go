package fakes

import (
	models "bosh/agent/applier/models"
)

type FakePackageApplier struct {
	ActionsCalled []string

	PreparedPackages []models.Package
	PrepareError     error

	AppliedPackages []models.Package
	ApplyError      error

	KeptOnlyPackages []models.Package
	KeepOnlyErr      error
}

func NewFakePackageApplier() *FakePackageApplier {
	return &FakePackageApplier{
		AppliedPackages: []models.Package{},
	}
}

func (s *FakePackageApplier) Prepare(pkg models.Package) error {
	s.ActionsCalled = append(s.ActionsCalled, "Prepare")
	s.PreparedPackages = append(s.PreparedPackages, pkg)
	return s.PrepareError
}

func (s *FakePackageApplier) Apply(pkg models.Package) error {
	s.ActionsCalled = append(s.ActionsCalled, "Apply")
	s.AppliedPackages = append(s.AppliedPackages, pkg)
	return s.ApplyError
}

func (s *FakePackageApplier) KeepOnly(pkgs []models.Package) error {
	s.ActionsCalled = append(s.ActionsCalled, "KeepOnly")
	s.KeptOnlyPackages = pkgs
	return s.KeepOnlyErr
}
