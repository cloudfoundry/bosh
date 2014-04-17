package fakes

import (
	boshpa "bosh/agent/applier/packageapplier"
)

type FakePackageApplierProvider struct {
	RootPackageApplier         *FakePackageApplier
	JobSpecificPackageAppliers map[string]*FakePackageApplier
}

func NewFakePackageApplierProvider() *FakePackageApplierProvider {
	return &FakePackageApplierProvider{
		JobSpecificPackageAppliers: map[string]*FakePackageApplier{},
	}
}

func (p *FakePackageApplierProvider) Root() boshpa.PackageApplier {
	if p.RootPackageApplier == nil {
		panic("Root package applier not found")
	}
	return p.RootPackageApplier
}

func (p *FakePackageApplierProvider) JobSpecific(jobName string) boshpa.PackageApplier {
	applier := p.JobSpecificPackageAppliers[jobName]
	if applier == nil {
		panic("Job specific package applier not found")
	}
	return applier
}
