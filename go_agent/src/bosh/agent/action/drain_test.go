package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestDrainRunReturns0(t *testing.T) {
	settings, platform, blobstore, taskService := getFakeFactoryDependencies()
	factory := NewFactory(settings, platform, blobstore, taskService)
	drain := factory.Create("drain")

	drainStatus, err := drain.Run([]byte{})
	assert.NoError(t, err)
	assert.Equal(t, 0, drainStatus)
}
