package packageapplier

import (
	"path/filepath"

	boshbc "bosh/agent/applier/bundlecollection"
	boshblob "bosh/blobstore"
	boshlog "bosh/logger"
	boshcmd "bosh/platform/commands"
	boshsys "bosh/system"
)

type concretePackageApplierProvider struct {
	installPath           string
	rootEnablePath        string
	jobSpecificEnablePath string
	name                  string

	blobstore  boshblob.Blobstore
	compressor boshcmd.Compressor
	fs         boshsys.FileSystem
	logger     boshlog.Logger
}

func NewConcretePackageApplierProvider(
	installPath, rootEnablePath, jobSpecificEnablePath, name string,
	blobstore boshblob.Blobstore,
	compressor boshcmd.Compressor,
	fs boshsys.FileSystem,
	logger boshlog.Logger,
) concretePackageApplierProvider {
	return concretePackageApplierProvider{
		installPath:           installPath,
		rootEnablePath:        rootEnablePath,
		jobSpecificEnablePath: jobSpecificEnablePath,
		name:       name,
		blobstore:  blobstore,
		compressor: compressor,
		fs:         fs,
		logger:     logger,
	}
}

// Root provides package applier that operates on system-wide packages.
// (e.g manages /var/vcap/packages/pkg-a -> /var/vcap/data/packages/pkg-a)
func (p concretePackageApplierProvider) Root() PackageApplier {
	return NewConcretePackageApplier(p.RootBundleCollection(), true, p.blobstore, p.compressor, p.fs, p.logger)
}

// JobSpecific provides package applier that operates on job-specific packages.
// (e.g manages /var/vcap/jobs/job-name/packages/pkg-a -> /var/vcap/data/packages/pkg-a)
func (p concretePackageApplierProvider) JobSpecific(jobName string) PackageApplier {
	enablePath := filepath.Join(p.jobSpecificEnablePath, jobName)
	packagesBc := boshbc.NewFileBundleCollection(p.installPath, enablePath, p.name, p.fs, p.logger)
	return NewConcretePackageApplier(packagesBc, false, p.blobstore, p.compressor, p.fs, p.logger)
}

func (p concretePackageApplierProvider) RootBundleCollection() boshbc.BundleCollection {
	return boshbc.NewFileBundleCollection(p.installPath, p.rootEnablePath, p.name, p.fs, p.logger)
}
