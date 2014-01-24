package mbus

import (
	boshlog "bosh/logger"
	"bosh/micro"
	fakeplatform "bosh/platform/fakes"
	boshdir "bosh/settings/directories"
	fakesettings "bosh/settings/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestHandlerProviderGetReturnsNatsHandler(t *testing.T) {
	provider, platform, dirProvider := buildProvider("nats://0.0.0.0")
	handler, err := provider.Get(platform, dirProvider)

	assert.NoError(t, err)
	assert.IsType(t, natsHandler{}, handler)
}

func TestHandlerProviderGetReturnsHttpsHandler(t *testing.T) {
	provider, platform, dirProvider := buildProvider("https://0.0.0.0")
	handler, err := provider.Get(platform, dirProvider)

	assert.NoError(t, err)
	assert.IsType(t, micro.HttpsHandler{}, handler)
}

func TestHandlerProviderGetReturnsAnErrorIfNotSupported(t *testing.T) {
	provider, platform, dirProvider := buildProvider("foo://0.0.0.0")
	_, err := provider.Get(platform, dirProvider)

	assert.Error(t, err)
}

func buildProvider(mbusUrl string) (provider mbusHandlerProvider, platform *fakeplatform.FakePlatform, dirProvider boshdir.DirectoriesProvider) {
	settings := &fakesettings.FakeSettingsService{MbusUrl: mbusUrl}
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	provider = NewHandlerProvider(settings, logger)

	platform = fakeplatform.NewFakePlatform()
	dirProvider = boshdir.NewDirectoriesProvider("/var/vcap")
	return
}
