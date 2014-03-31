package applyspec

import (
	models "bosh/agent/applier/models"
)

type ApplySpec interface {
	Jobs() []models.Job
	Packages() []models.Package
	MaxLogFileSize() string
}
