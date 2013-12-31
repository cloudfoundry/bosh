package monit

import (
	bosherr "bosh/errors"
	boshplatform "bosh/platform"
)

type clientProvider struct {
	platform boshplatform.Platform
}

func NewProvider(platform boshplatform.Platform) (provider clientProvider) {
	provider = clientProvider{
		platform: platform,
	}
	return
}

func (p clientProvider) Get() (client Client, err error) {
	monitUser, monitPassword, err := p.platform.GetMonitCredentials()
	if err != nil {
		err = bosherr.WrapError(err, "Getting monit credentials")
		return
	}

	client = NewHttpClient("127.0.0.1:2822", monitUser, monitPassword)
	return
}
