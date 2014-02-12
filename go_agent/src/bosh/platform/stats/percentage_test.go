package stats_test

import (
	. "bosh/platform/stats"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("fraction of100", func() {

			p := NewPercentage(50, 100)
			assert.Equal(GinkgoT(), p.FractionOf100(), 50)

			p = NewPercentage(50, 0)
			assert.Equal(GinkgoT(), p.FractionOf100(), 0)

			p = NewPercentage(0, 0)
			assert.Equal(GinkgoT(), p.FractionOf100(), 0)
		})
		It("format fraction of100", func() {

			p := NewPercentage(50, 100)
			assert.Equal(GinkgoT(), p.FormatFractionOf100(2), "50.00")
			assert.Equal(GinkgoT(), p.FormatFractionOf100(0), "50")

			p = NewPercentage(50, 0)
			assert.Equal(GinkgoT(), p.FormatFractionOf100(2), "0.00")
		})
	})
}
