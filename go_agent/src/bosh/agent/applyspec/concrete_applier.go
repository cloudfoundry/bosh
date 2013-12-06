package applyspec

import (
	bc "bosh/agent/applyspec/bundlecollection"
	models "bosh/agent/applyspec/models"
	pa "bosh/agent/applyspec/packageapplier"
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

func (s *concreteApplier) Apply(jobs []models.Job, packages []models.Package) error {
	for _, job := range jobs {
		err := s.applyJob(job)
		if err != nil {
			return err
		}
	}

	for _, pkg := range packages {
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
