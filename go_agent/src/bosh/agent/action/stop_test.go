package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestStopRunReturnsStopped(t *testing.T) {
	settings, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, platform, blobstore, taskService)
	stop := factory.Create("stop")

	stopped, err := stop.Run([]byte{})
	assert.NoError(t, err)
	assert.Equal(t, "stopped", stopped)
}
