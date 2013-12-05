package infrastructure

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
)

type provider struct {
	infrastructures map[string]Infrastructure
}

func NewProvider(logger boshlog.Logger) (p provider) {
	digDnsResolver := digDnsResolver{logger: logger}

	p.infrastructures = map[string]Infrastructure{
		"aws":   newAwsInfrastructure("http://169.254.169.254", digDnsResolver),
		"dummy": newDummyInfrastructure(),
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
