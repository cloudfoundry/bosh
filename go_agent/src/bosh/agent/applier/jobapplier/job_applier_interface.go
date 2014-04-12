package jobapplier

import (
	models "bosh/agent/applier/models"
)

type JobApplier interface {
	Prepare(job models.Job) error
	Apply(job models.Job) error
	Configure(job models.Job, jobIndex int) error
	KeepOnly(jobs []models.Job) error
}
