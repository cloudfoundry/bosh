package infrastructure

import (
	"errors"
	"fmt"
)

type provider struct {
	infrastructures map[string]Infrastructure
}

func NewProvider() (p provider) {
	p.infrastructures = map[string]Infrastructure{
		"aws": newAwsInfrastructure("http://169.254.169.254"),
	}
	return
}

func (p provider) Get(name string) (inf Infrastructure, err error) {
	inf, found := p.infrastructures[name]

	if !found {
		err = errors.New(fmt.Sprintf("Infrastructure %s could not be found", name))
	}
	return
}
