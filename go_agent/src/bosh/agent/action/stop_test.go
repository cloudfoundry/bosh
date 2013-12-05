package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestStopRunReturnsStopped(t *testing.T) {
	action := newStop()
	stopped, err := action.Run([]byte{})
	assert.NoError(t, err)
	assert.Equal(t, "stopped", stopped)
}
