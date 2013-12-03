package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestStartRunReturnsStarted(t *testing.T) {
	settings, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, platform, blobstore, taskService)
	start := factory.Create("start")

	started, err := start.Run([]byte{})
	assert.NoError(t, err)
	assert.Equal(t, "started", started)
}
