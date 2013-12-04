package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestPingRunReturnsPong(t *testing.T) {
	action := newPing()
	pong, err := action.Run([]byte{})
	assert.NoError(t, err)
	assert.Equal(t, "pong", pong)
}
