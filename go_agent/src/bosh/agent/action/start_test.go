package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestStartShouldBeSynchronous(t *testing.T) {
	action := newStart()
	assert.False(t, action.IsAsynchronous())
}

func TestStartRunReturnsStarted(t *testing.T) {
	action := newStart()
	started, err := action.Run()
	assert.NoError(t, err)
	assert.Equal(t, "started", started)
}
