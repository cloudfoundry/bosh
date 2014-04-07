package packageapplier

import (
	bc "bosh/agent/applier/bundlecollection"
	models "bosh/agent/applier/models"
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshcmd "bosh/platform/commands"
)

const logTag = "concretePackageApplier"

type concretePackageApplier struct {
	packagesBc bc.BundleCollection
	blobstore  boshblob.Blobstore
	compressor boshcmd.Compressor
	logger     boshlog.Logger
}

func NewConcretePackageApplier(
	packagesBc bc.BundleCollection,
	blobstore boshblob.Blobstore,
	compressor boshcmd.Compressor,
	logger boshlog.Logger,
) *concretePackageApplier {
	return &concretePackageApplier{
		packagesBc: packagesBc,
		blobstore:  blobstore,
		compressor: compressor,
		logger:     logger,
	}
}

func (s *concretePackageApplier) Apply(pkg models.Package) (err error) {
	s.logger.Debug(logTag, "Applying package %v", pkg)

	pkgBundle, err := s.packagesBc.Get(pkg)
	if err != nil {
		err = bosherr.WrapError(err, "Getting package bundle")
		return
	}

	_, packageDir, err := pkgBundle.Install()
	if err != nil {
		err = bosherr.WrapError(err, "Installling package directory")
		return
	}

	file, err := s.blobstore.Get(pkg.Source.BlobstoreID, pkg.Source.Sha1)
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

	_, _, err = pkgBundle.Enable()
	if err != nil {
		err = bosherr.WrapError(err, "Enabling package")
	}

	return
}

func (s *concretePackageApplier) KeepOnly(pkgs []models.Package) error {
	s.logger.Debug(logTag, "Keeping only packages %v", pkgs)

	installedBundles, err := s.packagesBc.List()
	if err != nil {
		return bosherr.WrapError(err, "Retrieving installed bundles")
	}

	for _, installedBundle := range installedBundles {
		var shouldKeep bool

		for _, pkg := range pkgs {
			pkgBundle, err := s.packagesBc.Get(pkg)
			if err != nil {
				return bosherr.WrapError(err, "Getting package bundle")
			}

			if pkgBundle == installedBundle {
				shouldKeep = true
				break
			}
		}

		if !shouldKeep {
			err = installedBundle.Disable()
			if err != nil {
				return bosherr.WrapError(err, "Disabling package bundle")
			}

			// If we uninstall the bundle first, and the disable failed (leaving the symlink),
			// then the next time bundle collection will not include bundle in its list
			// which means that symlink will never be deleted.
			err = installedBundle.Uninstall()
			if err != nil {
				return bosherr.WrapError(err, "Uninstalling package bundle")
			}
		}
	}

	return nil
}
