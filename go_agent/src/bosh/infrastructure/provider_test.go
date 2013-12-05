package infrastructure

import (
	boshlog "bosh/logger"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetReturnsAnAwsInfrastructure(t *testing.T) {
	provider := NewProvider(boshlog.NewLogger(boshlog.LEVEL_NONE))
	inf, err := provider.Get("aws")

	assert.NoError(t, err)
	assert.IsType(t, awsInfrastructure{}, inf)
}

func TestGetReturnsAnErrorOnUnknownInfrastructure(t *testing.T) {
	provider := NewProvider(boshlog.NewLogger(boshlog.LEVEL_NONE))
	_, err := provider.Get("some unknown infrastructure name")

	assert.Error(t, err)
}
