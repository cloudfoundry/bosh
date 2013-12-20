package packageapplier

import (
	bc "bosh/agent/applier/bundlecollection"
	models "bosh/agent/applier/models"
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshcmd "bosh/platform/commands"
)

type concretePackageApplier struct {
	packagesBc bc.BundleCollection
	blobstore  boshblob.Blobstore
	compressor boshcmd.Compressor
}

func NewConcretePackageApplier(
	packagesBc bc.BundleCollection,
	blobstore boshblob.Blobstore,
	compressor boshcmd.Compressor,
) *concretePackageApplier {
	return &concretePackageApplier{
		packagesBc: packagesBc,
		blobstore:  blobstore,
		compressor: compressor,
	}
}

func (s *concretePackageApplier) Apply(pkg models.Package) (err error) {
	_, packageDir, err := s.packagesBc.Install(pkg)
	if err != nil {
		err = bosherr.WrapError(err, "Installling package directory")
		return
	}

	file, err := s.blobstore.Get(pkg.Source.BlobstoreId, pkg.Source.Sha1)
	if err != nil {
		err = bosherr.WrapError(err, "Fetching package blob")
		return
	}

	defer s.blobstore.CleanUp(file)

	err = s.compressor.DecompressFileToDir(file, packageDir)
	if err != nil {
		err = bosherr.WrapError(err, "Decompressing package files")
		return
	}

	err = s.packagesBc.Enable(pkg)
	if err != nil {
		err = bosherr.WrapError(err, "Enabling package")
	}

	return
}
