package infrastructure

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshplatform "bosh/platform"
)

type Provider struct {
	infrastructures map[string]Infrastructure
}

func NewProvider(logger boshlog.Logger, platform boshplatform.Platform) (p Provider) {
	digDnsResolver := NewDigDnsResolver(logger)

	p.infrastructures = map[string]Infrastructure{
		"aws":     NewAwsInfrastructure("http://169.254.169.254", digDnsResolver, platform),
		"vsphere": NewVsphereInfrastructure(platform),
		"dummy":   NewDummyInfrastructure(platform.GetFs(), platform.GetDirProvider(), platform),
	}
	return
}

func (p Provider) Get(name string) (inf Infrastructure, err error) {
	inf, found := p.infrastructures[name]

	if !found {
		err = bosherr.New("Infrastructure %s could not be found", name)
	}
	return
}
