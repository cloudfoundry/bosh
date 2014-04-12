package packageapplier

import (
	models "bosh/agent/applier/models"
)

type PackageApplier interface {
	Prepare(pkg models.Package) error
	Apply(pkg models.Package) error
	KeepOnly(pkgs []models.Package) error
}
