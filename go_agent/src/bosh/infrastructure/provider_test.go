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

type cdromPlatform struct {
}

func (p cdromPlatform) GetFileContentsFromCDROM(filePath string) (contents []byte, err error) {
	return
}

func getNewProvider() (provider provider) {
	dirProvider := boshsys.NewDirectoriesProvider("/var/vcap")
	fs := fakefs.NewFakeFileSystem()

	provider = NewProvider(boshlog.NewLogger(boshlog.LEVEL_NONE), fs, dirProvider, cdromPlatform{})
	return
}
