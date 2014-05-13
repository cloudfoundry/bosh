package time_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/time"
)

var _ = Describe("concreteService", func() {
	Describe("Now", func() {
		It("returns current time", func() {
			service := NewConcreteService()
			t1 := service.Now()
			t2 := service.Now()
			Expect(float64(t2.Sub(t1))).To(BeNumerically(">", 0))
		})
	})
})
