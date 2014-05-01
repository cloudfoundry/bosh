package packageapplier

import (
	bc "bosh/agent/applier/bundlecollection"
	models "bosh/agent/applier/models"
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshcmd "bosh/platform/commands"
	boshsys "bosh/system"
)

const logTag = "concretePackageApplier"

type concretePackageApplier struct {
	packagesBc bc.BundleCollection

	// KeepOnly will permanently uninstall packages when operating as owner
	packagesBcOwner bool

	blobstore  boshblob.Blobstore
	compressor boshcmd.Compressor
	fs         boshsys.FileSystem
	logger     boshlog.Logger
}

func NewConcretePackageApplier(
	packagesBc bc.BundleCollection,
	packagesBcOwner bool,
	blobstore boshblob.Blobstore,
	compressor boshcmd.Compressor,
	fs boshsys.FileSystem,
	logger boshlog.Logger,
) *concretePackageApplier {
	return &concretePackageApplier{
		packagesBc:      packagesBc,
		packagesBcOwner: packagesBcOwner,
		blobstore:       blobstore,
		compressor:      compressor,
		fs:              fs,
		logger:          logger,
	}
}

func (s concretePackageApplier) Prepare(pkg models.Package) error {
	s.logger.Debug(logTag, "Preparing package %v", pkg)

	pkgBundle, err := s.packagesBc.Get(pkg)
	if err != nil {
		return bosherr.WrapError(err, "Getting package bundle")
	}

	pkgInstalled, err := pkgBundle.IsInstalled()
	if err != nil {
		return bosherr.WrapError(err, "Checking if package is installed")
	}

	if !pkgInstalled {
		err := s.downloadAndInstall(pkg, pkgBundle)
		if err != nil {
			return err
		}
	}

	return nil
}

func (s concretePackageApplier) Apply(pkg models.Package) error {
	s.logger.Debug(logTag, "Applying package %v", pkg)

	err := s.Prepare(pkg)
	if err != nil {
		return err
	}

	pkgBundle, err := s.packagesBc.Get(pkg)
	if err != nil {
		return bosherr.WrapError(err, "Getting package bundle")
	}

	_, _, err = pkgBundle.Enable()
	if err != nil {
		return bosherr.WrapError(err, "Enabling package")
	}

	return nil
}

func (s *concretePackageApplier) downloadAndInstall(pkg models.Package, pkgBundle bc.Bundle) error {
	tmpDir, err := s.fs.TempDir("bosh-agent-applier-packageapplier-ConcretePackageApplier-Apply")
	if err != nil {
		return bosherr.WrapError(err, "Getting temp dir")
	}

	defer s.fs.RemoveAll(tmpDir)

	file, err := s.blobstore.Get(pkg.Source.BlobstoreID, pkg.Source.Sha1)
	if err != nil {
		return bosherr.WrapError(err, "Fetching package blob")
	}

	defer s.blobstore.CleanUp(file)

	err = s.compressor.DecompressFileToDir(file, tmpDir)
	if err != nil {
		return bosherr.WrapError(err, "Decompressing package files")
	}

	_, _, err = pkgBundle.Install(tmpDir)
	if err != nil {
		return bosherr.WrapError(err, "Installling package directory")
	}

	return nil
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

			if s.packagesBcOwner {
				// If we uninstall the bundle first, and the disable failed (leaving the symlink),
				// then the next time bundle collection will not include bundle in its list
				// which means that symlink will never be deleted.
				err = installedBundle.Uninstall()
				if err != nil {
					return bosherr.WrapError(err, "Uninstalling package bundle")
				}
			}
		}
	}

	return nil
}
