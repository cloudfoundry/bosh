package infrastructure

import (
	bosherr "bosh/errors"
)

type provider struct {
	infrastructures map[string]Infrastructure
}

func NewProvider() (p provider) {
	p.infrastructures = map[string]Infrastructure{
		"aws":   newAwsInfrastructure("http://169.254.169.254", digDnsResolver{}),
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
