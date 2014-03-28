package fakes

import (
	models "bosh/agent/applier/models"
)

type FakeApplySpec struct {
	JobResults           []models.Job
	PackageResults       []models.Package
	MaxLogFileSizeResult string
}

func (s FakeApplySpec) Jobs() []models.Job {
	return s.JobResults
}

func (s FakeApplySpec) Packages() []models.Package {
	return s.PackageResults
}

func (s FakeApplySpec) MaxLogFileSize() string {
	return s.MaxLogFileSizeResult
}
