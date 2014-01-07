package infrastructure

import (
	boshlog "bosh/logger"
	boshsys "bosh/settings/directories"
	fakefs "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetReturnsAnAwsInfrastructure(t *testing.T) {
	provider := getNewProvider()
	inf, err := provider.Get("aws")

	assert.NoError(t, err)
	assert.IsType(t, awsInfrastructure{}, inf)
}

func TestGetReturnsAnErrorOnUnknownInfrastructure(t *testing.T) {
	provider := getNewProvider()
	_, err := provider.Get("some unknown infrastructure name")

	assert.Error(t, err)
}

func getNewProvider() (provider provider) {
	dirProvider := boshsys.NewDirectoriesProvider("/var/vcap")
	fs := fakefs.NewFakeFileSystem()

	provider = NewProvider(boshlog.NewLogger(boshlog.LEVEL_NONE), fs, dirProvider)
	return
}
