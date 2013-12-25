package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestPingShouldBeSynchronous(t *testing.T) {
	action := newPing()
	assert.False(t, action.IsAsynchronous())
}

func TestPingRunReturnsPong(t *testing.T) {
	action := newPing()
	pong, err := action.Run()
	assert.NoError(t, err)
	assert.Equal(t, "pong", pong)
}
