package infrastructure

import (
	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetReturnsAnAwsInfrastructure(t *testing.T) {
	provider := getNewProvider()
	inf, err := provider.Get("aws")

	assert.NoError(t, err)
	assert.IsType(t, awsInfrastructure{}, inf)
}

func TestGetReturnsVsphereInfrastructure(t *testing.T) {
	provider := getNewProvider()
	inf, err := provider.Get("vsphere")

	assert.NoError(t, err)
	assert.IsType(t, vsphereInfrastructure{}, inf)
}

func TestGetReturnsAnErrorOnUnknownInfrastructure(t *testing.T) {
	provider := getNewProvider()
	_, err := provider.Get("some unknown infrastructure name")

	assert.Error(t, err)
}

func getNewProvider() (provider provider) {
	platform := fakeplatform.NewFakePlatform()

	provider = NewProvider(boshlog.NewLogger(boshlog.LEVEL_NONE), platform)
	return
}
