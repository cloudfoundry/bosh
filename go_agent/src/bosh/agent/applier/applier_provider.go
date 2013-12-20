package applier

import (
	bc "bosh/agent/applier/bundlecollection"
	ja "bosh/agent/applier/jobapplier"
	pa "bosh/agent/applier/packageapplier"
	boshblob "bosh/blobstore"
	boshmon "bosh/monitor"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type ApplierProvider struct {
	platform  boshplatform.Platform
	blobstore boshblob.Blobstore
	monitor   boshmon.Monitor
}

func NewApplierProvider(platform boshplatform.Platform, blobstore boshblob.Blobstore, monitor boshmon.Monitor) (p ApplierProvider) {
	p.platform = platform
	p.blobstore = blobstore
	p.monitor = monitor
	return
}

func (p ApplierProvider) Get() (applier Applier) {
	jobsBc := bc.NewFileBundleCollection(
		"jobs", boshsettings.VCAP_BASE_DIR, p.platform.GetFs())

	jobApplier := ja.NewRenderedJobApplier(
		jobsBc,
		p.blobstore,
		p.platform.GetCompressor(),
		p.monitor,
	)

	packagesBc := bc.NewFileBundleCollection(
		"packages", boshsettings.VCAP_BASE_DIR, p.platform.GetFs())

	packageApplier := pa.NewConcretePackageApplier(
		packagesBc,
		p.blobstore,
		p.platform.GetCompressor(),
	)

	return NewConcreteApplier(jobApplier, packageApplier, p.platform, p.monitor)
}
