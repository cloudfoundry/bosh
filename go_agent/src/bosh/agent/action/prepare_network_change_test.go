package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

// This may change to be asynchronous when the action is actually implemented
func TestPrepareNetworkChangeShouldBeSynchronous(t *testing.T) {
	action := newPrepareNetworkChange()
	assert.False(t, action.IsAsynchronous())
}

func TestPrepareNetworkChangeReturnsTrue(t *testing.T) {
	action := newPrepareNetworkChange()
	resp, err := action.Run()
	assert.NoError(t, err)
	assert.Equal(t, true, resp)
}
