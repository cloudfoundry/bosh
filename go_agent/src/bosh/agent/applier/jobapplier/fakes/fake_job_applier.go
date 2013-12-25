package fakes

import models "bosh/agent/applier/models"

type FakeJobApplier struct {
	AppliedJobs []models.Job
	ApplyError  error

	ConfiguredJobs       []models.Job
	ConfiguredJobIndices []int
	ConfigureError       error
}

func NewFakeJobApplier() *FakeJobApplier {
	return &FakeJobApplier{
		AppliedJobs: make([]models.Job, 0),
	}
}

func (s *FakeJobApplier) Apply(job models.Job) error {
	if s.ApplyError != nil {
		return s.ApplyError
	}

	s.AppliedJobs = append(s.AppliedJobs, job)
	return nil
}

func (s *FakeJobApplier) Configure(job models.Job, jobIndex int) error {
	if s.ConfigureError != nil {
		return s.ConfigureError
	}

	s.ConfiguredJobs = append(s.ConfiguredJobs, job)
	s.ConfiguredJobIndices = append(s.ConfiguredJobIndices, jobIndex)
	return nil
}
