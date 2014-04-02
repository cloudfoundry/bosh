package stats_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/stats"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("fraction of100", func() {

			p := NewPercentage(50, 100)
			Expect(p.FractionOf100()).To(Equal(float64(50)))

			p = NewPercentage(50, 0)
			Expect(p.FractionOf100()).To(Equal(float64(0)))

			p = NewPercentage(0, 0)
			Expect(p.FractionOf100()).To(Equal(float64(0)))
		})
		It("format fraction of100", func() {

			p := NewPercentage(50, 100)
			Expect(p.FormatFractionOf100(2)).To(Equal("50.00"))
			Expect(p.FormatFractionOf100(0)).To(Equal("50"))

			p = NewPercentage(50, 0)
			Expect(p.FormatFractionOf100(2)).To(Equal("0.00"))
		})
	})
}
