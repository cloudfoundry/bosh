package stats_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/stats"
)

var _ = Describe("CPUStats", func() {
	Describe("UserPercent", func() {
		It("returns user percentage", func() {
			cpuStats := CPUStats{
				User:  100,
				Nice:  200,
				Sys:   300,
				Wait:  400,
				Total: 1000,
			}

			Expect(cpuStats.UserPercent().FormatFractionOf100(1)).To(Equal("30.0"))
		})
	})
})
