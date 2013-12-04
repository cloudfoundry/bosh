package applyspec

import bc "bosh/agent/applyspec/bundlecollection"

type concreteApplier struct {
	jobsBc     bc.BundleCollection
	packagesBc bc.BundleCollection
}

func NewConcreteApplier(jobsBc bc.BundleCollection, packagesBc bc.BundleCollection) *concreteApplier {
	return &concreteApplier{jobsBc: jobsBc, packagesBc: packagesBc}
}

func (s *concreteApplier) Apply(jobs []Job, packages []Package) error {
	for _, job := range jobs {
		err := s.applyBundle(s.jobsBc, job)
		if err != nil {
			return err
		}
	}

	for _, pkg := range packages {
		err := s.applyBundle(s.packagesBc, pkg)
		if err != nil {
			return err
		}
	}

	return nil
}

func (s *concreteApplier) applyBundle(collection bc.BundleCollection, bundle bc.Bundle) error {
	_, err := collection.Install(bundle)
	if err != nil {
		return err
	}

	err = collection.Enable(bundle)
	if err != nil {
		return err
	}

	return nil
}
