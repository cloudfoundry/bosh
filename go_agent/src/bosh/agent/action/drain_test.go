package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestDrainShouldBeAsynchronous(t *testing.T) {
	action := newDrain()
	assert.True(t, action.IsAsynchronous())
}

func TestDrainRunReturns0(t *testing.T) {
	action := newDrain()
	drainStatus, err := action.Run()
	assert.NoError(t, err)
	assert.Equal(t, 0, drainStatus)
}
