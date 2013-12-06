package packageapplier

import (
	bc "bosh/agent/applier/bundlecollection"
	models "bosh/agent/applier/models"
	boshblob "bosh/blobstore"
	boshdisk "bosh/platform/disk"
)

type concretePackageApplier struct {
	packagesBc bc.BundleCollection
	blobstore  boshblob.Blobstore
	compressor boshdisk.Compressor
}

func NewConcretePackageApplier(
	packagesBc bc.BundleCollection,
	blobstore boshblob.Blobstore,
	compressor boshdisk.Compressor,
) *concretePackageApplier {
	return &concretePackageApplier{
		packagesBc: packagesBc,
		blobstore:  blobstore,
		compressor: compressor,
	}
}

func (s *concretePackageApplier) Apply(pkg models.Package) error {
	packageDir, err := s.packagesBc.Install(pkg)
	if err != nil {
		return err
	}

	file, err := s.blobstore.Get(pkg.Source.BlobstoreId)
	if err != nil {
		return err
	}

	defer s.blobstore.CleanUp(file)

	err = s.compressor.DecompressFileToDir(file, packageDir)
	if err != nil {
		return err
	}

	return s.packagesBc.Enable(pkg)
}
