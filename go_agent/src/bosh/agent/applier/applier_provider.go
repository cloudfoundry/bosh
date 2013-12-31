package applier

import (
	bc "bosh/agent/applier/bundlecollection"
	ja "bosh/agent/applier/jobapplier"
	pa "bosh/agent/applier/packageapplier"
	boshblob "bosh/blobstore"
	boshjobsuper "bosh/jobsupervisor"
	boshplatform "bosh/platform"
	boshdirs "bosh/settings/directories"
	"path/filepath"
)

type ApplierProvider struct {
	platform      boshplatform.Platform
	blobstore     boshblob.Blobstore
	jobSupervisor boshjobsuper.JobSupervisor
	dirProvider   boshdirs.DirectoriesProvider
}

func NewApplierProvider(platform boshplatform.Platform, blobstore boshblob.Blobstore, jobSupervisor boshjobsuper.JobSupervisor, dirProvider boshdirs.DirectoriesProvider) (p ApplierProvider) {
	p.platform = platform
	p.blobstore = blobstore
	p.jobSupervisor = jobSupervisor
	p.dirProvider = dirProvider
	return
}

func (p ApplierProvider) Get() (applier Applier) {
	installPath := filepath.Join(p.dirProvider.BaseDir(), "data")

	jobsBc := bc.NewFileBundleCollection(installPath, p.dirProvider.BaseDir(), "jobs", p.platform.GetFs())

	jobApplier := ja.NewRenderedJobApplier(
		jobsBc,
		p.blobstore,
		p.platform.GetCompressor(),
		p.jobSupervisor,
	)

	packagesBc := bc.NewFileBundleCollection(installPath, p.dirProvider.BaseDir(), "packages", p.platform.GetFs())

	packageApplier := pa.NewConcretePackageApplier(
		packagesBc,
		p.blobstore,
		p.platform.GetCompressor(),
	)

	return NewConcreteApplier(jobApplier, packageApplier, p.platform, p.jobSupervisor, p.dirProvider)
}
