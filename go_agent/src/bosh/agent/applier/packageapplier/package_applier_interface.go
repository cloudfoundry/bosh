package packageapplier

import models "bosh/agent/applier/models"

type PackageApplier interface {
	Apply(pkg models.Package) error
}
