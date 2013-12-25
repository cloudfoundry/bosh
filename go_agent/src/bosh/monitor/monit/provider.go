package monit

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
)

type monitClientProvider struct {
	platform boshplatform.Platform
}

func NewProvider(platform boshplatform.Platform) (provider monitClientProvider) {
	provider = monitClientProvider{
		platform: platform,
	}
	return
}

func (p monitClientProvider) Get() (client MonitClient, err error) {
	monitUser, monitPassword, err := p.platform.GetMonitCredentials()
	if err != nil {
		err = bosherr.WrapError(err, "Getting monit credentials")
		return
	}

	client = NewHttpMonitClient("127.0.0.1:2822", monitUser, monitPassword)
	return
}
