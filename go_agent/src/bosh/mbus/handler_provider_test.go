package mbus_test

import (
	boshlog "bosh/logger"
	. "bosh/mbus"
	"bosh/micro"
	fakeplatform "bosh/platform/fakes"
	boshdir "bosh/settings/directories"
	fakesettings "bosh/settings/fakes"
	"github.com/cloudfoundry/yagnats"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestHandlerProviderGetReturnsNatsHandler(t *testing.T) {
	deps, provider := buildProvider("nats://0.0.0.0")
	handler, err := provider.Get(deps.platform, deps.dirProvider)

	assert.NoError(t, err)
	assert.IsType(t, NewNatsHandler(deps.settings, deps.logger, yagnats.NewClient()), handler)
}

func TestHandlerProviderGetReturnsHttpsHandler(t *testing.T) {
	deps, provider := buildProvider("https://0.0.0.0")
	handler, err := provider.Get(deps.platform, deps.dirProvider)

	assert.NoError(t, err)
	assert.IsType(t, micro.HttpsHandler{}, handler)
}

func TestHandlerProviderGetReturnsAnErrorIfNotSupported(t *testing.T) {
	deps, provider := buildProvider("foo://0.0.0.0")
	_, err := provider.Get(deps.platform, deps.dirProvider)

	assert.Error(t, err)
}

type providerDeps struct {
	settings    *fakesettings.FakeSettingsService
	platform    *fakeplatform.FakePlatform
	dirProvider boshdir.DirectoriesProvider
	logger      boshlog.Logger
}

func buildProvider(mbusUrl string) (deps providerDeps, provider MbusHandlerProvider) {
	deps.settings = &fakesettings.FakeSettingsService{MbusUrl: mbusUrl}
	deps.logger = boshlog.NewLogger(boshlog.LEVEL_NONE)
	provider = NewHandlerProvider(deps.settings, deps.logger)

	deps.platform = fakeplatform.NewFakePlatform()
	deps.dirProvider = boshdir.NewDirectoriesProvider("/var/vcap")
	return
}
