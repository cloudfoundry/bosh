package fakes

import models "bosh/agent/applier/models"

type FakeJobApplier struct {
	AppliedJobs []models.Job
	ApplyError  error
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
