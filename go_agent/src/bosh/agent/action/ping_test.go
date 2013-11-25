package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestPingRunReturnsPong(t *testing.T) {
	settings, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, platform, blobstore, taskService)
	ping := factory.Create("ping")

	pong, err := ping.Run([]byte{})
	assert.NoError(t, err)
	assert.Equal(t, "pong", pong)
}
