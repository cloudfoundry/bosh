package fakes

import boshas "bosh/agent/applyspec"

type FakeApplier struct {
	AppliedJobs     []boshas.Job
	AppliedPackages []boshas.Package
	ApplyError      error
}

func NewFakeApplier() *FakeApplier {
	return &FakeApplier{}
}

func (s *FakeApplier) Apply(jobs []boshas.Job, packages []boshas.Package) error {
	if s.ApplyError != nil {
		return s.ApplyError
	}

	s.AppliedJobs = jobs
	s.AppliedPackages = packages
	return nil
}
