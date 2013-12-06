package fakes

import models "bosh/agent/applyspec/models"

type FakeApplier struct {
	AppliedJobs     []models.Job
	AppliedPackages []models.Package
	ApplyError      error
}

func NewFakeApplier() *FakeApplier {
	return &FakeApplier{}
}

func (s *FakeApplier) Apply(jobs []models.Job, packages []models.Package) error {
	if s.ApplyError != nil {
		return s.ApplyError
	}

	s.AppliedJobs = jobs
	s.AppliedPackages = packages
	return nil
}
