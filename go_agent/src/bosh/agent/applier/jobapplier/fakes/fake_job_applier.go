package fakes

import (
	models "bosh/agent/applier/models"
)

type FakeJobApplier struct {
	PreparedJobs []models.Job
	PrepareError error

	AppliedJobs []models.Job
	ApplyError  error

	ConfiguredJobs       []models.Job
	ConfiguredJobIndices []int
	ConfigureError       error

	KeepOnlyJobs []models.Job
	KeepOnlyErr  error
}

func NewFakeJobApplier() *FakeJobApplier {
	return &FakeJobApplier{
		AppliedJobs: []models.Job{},
	}
}

func (s *FakeJobApplier) Prepare(job models.Job) error {
	s.PreparedJobs = append(s.PreparedJobs, job)
	return s.PrepareError
}

func (s *FakeJobApplier) Apply(job models.Job) error {
	s.AppliedJobs = append(s.AppliedJobs, job)
	return s.ApplyError
}

func (s *FakeJobApplier) Configure(job models.Job, jobIndex int) error {
	s.ConfiguredJobs = append(s.ConfiguredJobs, job)
	s.ConfiguredJobIndices = append(s.ConfiguredJobIndices, jobIndex)
	return s.ConfigureError
}

func (s *FakeJobApplier) KeepOnly(jobs []models.Job) error {
	s.KeepOnlyJobs = jobs
	return s.KeepOnlyErr
}
