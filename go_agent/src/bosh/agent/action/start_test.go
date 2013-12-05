package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestStartRunReturnsStarted(t *testing.T) {
	action := newStart()
	started, err := action.Run([]byte{})
	assert.NoError(t, err)
	assert.Equal(t, "started", started)
}
