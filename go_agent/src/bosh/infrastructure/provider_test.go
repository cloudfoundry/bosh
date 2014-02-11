package infrastructure_test

import (
	. "bosh/infrastructure"
	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetReturnsAnAwsInfrastructure(t *testing.T) {
	logger, platform, provider := getNewProvider()
	inf, err := provider.Get("aws")

	assert.NoError(t, err)
	assert.IsType(t, NewAwsInfrastructure("http://169.254.169.254", NewDigDnsResolver(logger), platform), inf)
}

func TestGetReturnsVsphereInfrastructure(t *testing.T) {
	_, platform, provider := getNewProvider()
	inf, err := provider.Get("vsphere")

	assert.NoError(t, err)
	assert.IsType(t, NewVsphereInfrastructure(platform), inf)
}

func TestGetReturnsAnErrorOnUnknownInfrastructure(t *testing.T) {
	_, _, provider := getNewProvider()
	_, err := provider.Get("some unknown infrastructure name")

	assert.Error(t, err)
}

func getNewProvider() (logger boshlog.Logger, platform *fakeplatform.FakePlatform, provider Provider) {
	platform = fakeplatform.NewFakePlatform()
	logger = boshlog.NewLogger(boshlog.LEVEL_NONE)
	provider = NewProvider(logger, platform)
	return
}
