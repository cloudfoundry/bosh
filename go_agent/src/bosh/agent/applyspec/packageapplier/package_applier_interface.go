package packageapplier

import models "bosh/agent/applyspec/models"

type PackageApplier interface {
	Apply(pkg models.Package) error
}
