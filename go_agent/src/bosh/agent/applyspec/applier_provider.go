package applyspec

import (
	boshbc "bosh/agent/applyspec/bundlecollection"
	boshblobstore "bosh/blobstore"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type ApplierProvider struct {
	platform  boshplatform.Platform
	blobstore boshblobstore.Blobstore
}

func NewApplierProvider(platform boshplatform.Platform, blobstore boshblobstore.Blobstore) (p ApplierProvider) {
	p.platform = platform
	p.blobstore = blobstore
	return
}

func (p ApplierProvider) Get() (applier Applier) {
	jobsBc := boshbc.NewFileBundleCollection(
		"jobs", boshsettings.VCAP_BASE_DIR, p.platform.GetFs())

	packagesBc := boshbc.NewFileBundleCollection(
		"packages", boshsettings.VCAP_BASE_DIR, p.platform.GetFs())

	return NewConcreteApplier(jobsBc, packagesBc, p.blobstore, p.platform.GetCompressor())
}
