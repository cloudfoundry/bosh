package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestDrainRunReturns0(t *testing.T) {
	action := newDrain()
	drainStatus, err := action.Run([]byte{})
	assert.NoError(t, err)
	assert.Equal(t, 0, drainStatus)
}
