package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestPingRunReturnsPong(t *testing.T) {
	settings, fs, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, fs, taskService)
	ping := factory.Create("ping")

	pong, err := ping.Run([]byte{})
	assert.NoError(t, err)
	assert.Equal(t, "pong", pong)
}
