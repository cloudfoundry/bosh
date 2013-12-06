package applier

import (
	bc "bosh/agent/applier/bundlecollection"
	pa "bosh/agent/applier/packageapplier"
	boshblob "bosh/blobstore"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type ApplierProvider struct {
	platform  boshplatform.Platform
	blobstore boshblob.Blobstore
}

func NewApplierProvider(platform boshplatform.Platform, blobstore boshblob.Blobstore) (p ApplierProvider) {
	p.platform = platform
	p.blobstore = blobstore
	return
}

func (p ApplierProvider) Get() (applier Applier) {
	jobsBc := bc.NewFileBundleCollection(
		"jobs", boshsettings.VCAP_BASE_DIR, p.platform.GetFs())

	packagesBc := bc.NewFileBundleCollection(
		"packages", boshsettings.VCAP_BASE_DIR, p.platform.GetFs())

	packageApplier := pa.NewConcretePackageApplier(
		packagesBc,
		p.blobstore,
		p.platform.GetCompressor(),
	)

	return NewConcreteApplier(jobsBc, packageApplier)
}
