package applyspec

import (
	bc "bosh/agent/applyspec/bundlecollection"
	boshblobstore "bosh/blobstore"
	boshdisk "bosh/platform/disk"
)

type concreteApplier struct {
	jobsBc     bc.BundleCollection
	packagesBc bc.BundleCollection
	blobstore  boshblobstore.Blobstore
	compressor boshdisk.Compressor
}

func NewConcreteApplier(
	jobsBc bc.BundleCollection,
	packagesBc bc.BundleCollection,
	blobstore boshblobstore.Blobstore,
	compressor boshdisk.Compressor,
) *concreteApplier {
	return &concreteApplier{
		jobsBc:     jobsBc,
		packagesBc: packagesBc,
		blobstore:  blobstore,
		compressor: compressor,
	}
}

func (s *concreteApplier) Apply(jobs []Job, packages []Package) error {
	for _, job := range jobs {
		err := s.applyBundle(s.jobsBc, job)
		if err != nil {
			return err
		}
	}

	for _, pkg := range packages {
		err := s.applyPackage(pkg)
		if err != nil {
			return err
		}
	}

	return nil
}

func (s *concreteApplier) applyPackage(pkg Package) (err error) {
	packageDir, err := s.packagesBc.Install(pkg)
	if err != nil {
		return
	}

	file, err := s.blobstore.Get(pkg.BlobstoreId)
	if err != nil {
		return
	}

	defer s.blobstore.CleanUp(file)

	err = s.compressor.DecompressFileToDir(file, packageDir)
	if err != nil {
		return
	}

	return s.packagesBc.Enable(pkg)
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
