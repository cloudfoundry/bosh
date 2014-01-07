package infrastructure

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
)

type provider struct {
	infrastructures map[string]Infrastructure
}

func NewProvider(logger boshlog.Logger, fs boshsys.FileSystem, dirProvider boshdir.DirectoriesProvider) (p provider) {
	digDnsResolver := digDnsResolver{logger: logger}

	p.infrastructures = map[string]Infrastructure{
		"aws":   newAwsInfrastructure("http://169.254.169.254", digDnsResolver),
		"dummy": newDummyInfrastructure(fs, dirProvider),
	}
	return
}

func (p provider) Get(name string) (inf Infrastructure, err error) {
	inf, found := p.infrastructures[name]

	if !found {
		err = bosherr.New("Infrastructure %s could not be found", name)
	}
	return
}
