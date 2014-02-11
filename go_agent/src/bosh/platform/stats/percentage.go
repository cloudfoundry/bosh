package stats

import "fmt"

type Percentage struct {
	part  uint64
	total uint64
}

func NewPercentage(part, total uint64) (percentage Percentage) {
	percentage.part = part
	percentage.total = total
	return
}

func (p Percentage) FractionOf100() float64 {
	if p.total <= 0 {
		return 0
	}

	return float64(p.part) / float64(p.total) * 100
}

func (p Percentage) FormatFractionOf100(numberOfDecimals int) string {
	format := fmt.Sprintf("%%.%df", numberOfDecimals)
	return fmt.Sprintf(format, p.FractionOf100())
}
