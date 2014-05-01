package monit

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshplatform "bosh/platform"
	"net/http"
	"time"
)

type clientProvider struct {
	platform boshplatform.Platform
	logger   boshlog.Logger
}

func NewProvider(platform boshplatform.Platform, logger boshlog.Logger) (provider clientProvider) {
	provider = clientProvider{
		platform: platform,
		logger:   logger,
	}
	return
}

func (p clientProvider) Get() (client Client, err error) {
	monitUser, monitPassword, err := p.platform.GetMonitCredentials()
	if err != nil {
		err = bosherr.WrapError(err, "Getting monit credentials")
		return
	}

	client = NewHTTPClient("127.0.0.1:2822", monitUser, monitPassword, http.DefaultClient, 1*time.Second, p.logger)
	return
}
