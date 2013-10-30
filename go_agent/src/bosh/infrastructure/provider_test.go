package infrastructure

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetReturnsAnAwsInfrastructure(t *testing.T) {
	provider := NewProvider()
	inf, err := provider.Get("aws")

	assert.NoError(t, err)
	assert.IsType(t, awsInfrastructure{}, inf)
}

func TestGetReturnsAnErrorOnUnknownInfrastructure(t *testing.T) {
	provider := NewProvider()
	_, err := provider.Get("some unknown infrastructure name")

	assert.Error(t, err)
}
