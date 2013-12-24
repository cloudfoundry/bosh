package applier

import (
	bc "bosh/agent/applier/bundlecollection"
	ja "bosh/agent/applier/jobapplier"
	pa "bosh/agent/applier/packageapplier"
	boshblob "bosh/blobstore"
	boshmon "bosh/monitor"
	boshplatform "bosh/platform"
	"path/filepath"
)

type ApplierProvider struct {
	platform  boshplatform.Platform
	blobstore boshblob.Blobstore
	monitor   boshmon.Monitor
	baseDir   string
}

func NewApplierProvider(platform boshplatform.Platform, blobstore boshblob.Blobstore, monitor boshmon.Monitor, baseDir string) (p ApplierProvider) {
	p.platform = platform
	p.blobstore = blobstore
	p.monitor = monitor
	p.baseDir = baseDir
	return
}

func (p ApplierProvider) Get() (applier Applier) {
	installPath := filepath.Join(p.baseDir, "data")

	jobsBc := bc.NewFileBundleCollection(installPath, p.baseDir, "jobs", p.platform.GetFs())

	jobApplier := ja.NewRenderedJobApplier(
		jobsBc,
		p.blobstore,
		p.platform.GetCompressor(),
		p.monitor,
	)

	packagesBc := bc.NewFileBundleCollection(installPath, p.baseDir, "packages", p.platform.GetFs())

	packageApplier := pa.NewConcretePackageApplier(
		packagesBc,
		p.blobstore,
		p.platform.GetCompressor(),
	)

	return NewConcreteApplier(jobApplier, packageApplier, p.platform, p.monitor)
}
