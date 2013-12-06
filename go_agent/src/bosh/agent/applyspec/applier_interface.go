package applyspec

import models "bosh/agent/applyspec/models"

type Applier interface {
	Apply(jobs []models.Job, packages []models.Package) error
}
