package jobapplier

import models "bosh/agent/applier/models"

type JobApplier interface {
	Apply(job models.Job) error
	Configure(job models.Job, jobIndex int) error
}
