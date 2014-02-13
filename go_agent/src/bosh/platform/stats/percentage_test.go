package stats_test

import (
	. "bosh/platform/stats"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestFractionOf100(t *testing.T) {
	p := NewPercentage(50, 100)
	assert.Equal(t, p.FractionOf100(), 50)

	p = NewPercentage(50, 0)
	assert.Equal(t, p.FractionOf100(), 0)

	p = NewPercentage(0, 0)
	assert.Equal(t, p.FractionOf100(), 0)
}

func TestFormatFractionOf100(t *testing.T) {
	p := NewPercentage(50, 100)
	assert.Equal(t, p.FormatFractionOf100(2), "50.00")
	assert.Equal(t, p.FormatFractionOf100(0), "50")

	p = NewPercentage(50, 0)
	assert.Equal(t, p.FormatFractionOf100(2), "0.00")
}
