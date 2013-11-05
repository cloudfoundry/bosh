package infrastructure

import (
	"bosh/settings"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetSettings(t *testing.T) {
	dummy := newDummyInfrastructure()
	s, err := dummy.GetSettings()
	assert.NoError(t, err)
	assert.Equal(t, s, settings.Settings{Mbus: "nats://foo:bar@127.0.0.1:4222"})
}
