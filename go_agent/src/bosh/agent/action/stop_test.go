package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestStopShouldBeAsynchronous(t *testing.T) {
	action := newStop()
	assert.True(t, action.IsAsynchronous())
}

func TestStopRunReturnsStopped(t *testing.T) {
	action := newStop()
	stopped, err := action.Run()
	assert.NoError(t, err)
	assert.Equal(t, "stopped", stopped)
}
