package jobapplier

import models "bosh/agent/applier/models"

type JobApplier interface {
	Apply(job models.Job) error
}
