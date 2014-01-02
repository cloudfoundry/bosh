package stats

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestFractionOf100(t *testing.T) {
	p := Percentage{50, 100}
	assert.Equal(t, p.FractionOf100(), 50)

	p = Percentage{50, 0}
	assert.Equal(t, p.FractionOf100(), 0)

	p = Percentage{0, 0}
	assert.Equal(t, p.FractionOf100(), 0)
}

func TestFormatFractionOf100(t *testing.T) {
	p := Percentage{50, 100}
	assert.Equal(t, p.FormatFractionOf100(2), "50.00")
	assert.Equal(t, p.FormatFractionOf100(0), "50")

	p = Percentage{50, 0}
	assert.Equal(t, p.FormatFractionOf100(2), "0.00")
}
