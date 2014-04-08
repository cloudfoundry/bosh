package fakes

import (
	models "bosh/agent/applier/models"
)

type FakePackageApplier struct {
	ActionsCalled []string

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
