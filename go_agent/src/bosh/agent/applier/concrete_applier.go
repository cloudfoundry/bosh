package applier

import (
	as "bosh/agent/applier/applyspec"
	bc "bosh/agent/applier/bundlecollection"
	models "bosh/agent/applier/models"
	pa "bosh/agent/applier/packageapplier"
)

type concreteApplier struct {
	jobsBc         bc.BundleCollection
	packageApplier pa.PackageApplier
}

func NewConcreteApplier(
	jobsBc bc.BundleCollection,
	packageApplier pa.PackageApplier,
) *concreteApplier {
	return &concreteApplier{
		jobsBc:         jobsBc,
		packageApplier: packageApplier,
	}
}

func (s *concreteApplier) Apply(applySpec as.ApplySpec) error {
	for _, job := range applySpec.Jobs() {
		err := s.applyJob(job)
		if err != nil {
			return err
		}
	}

	for _, pkg := range applySpec.Packages() {
		err := s.packageApplier.Apply(pkg)
		if err != nil {
			return err
		}
	}

	return nil
}

func (s *concreteApplier) applyJob(job models.Job) error {
	_, err := s.jobsBc.Install(job)
	if err != nil {
		return err
	}

	err = s.jobsBc.Enable(job)
	if err != nil {
		return err
	}

	return nil
}
