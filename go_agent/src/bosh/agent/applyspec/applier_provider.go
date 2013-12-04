package applyspec

import (
	boshbc "bosh/agent/applyspec/bundlecollection"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
)

type ApplierProvider struct {
	fs boshsys.FileSystem
}

func NewApplierProvider(fs boshsys.FileSystem) (p ApplierProvider) {
	p.fs = fs
	return
}

func (p ApplierProvider) Get() (applier Applier) {
	return NewConcreteApplier(
		boshbc.NewFileBundleCollection("jobs", boshsettings.VCAP_BASE_DIR, p.fs),
		boshbc.NewFileBundleCollection("packages", boshsettings.VCAP_BASE_DIR, p.fs),
	)
}
