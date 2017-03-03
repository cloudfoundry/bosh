package errors_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "github.com/cloudfoundry/bosh-utils/errors"
)

var _ = Describe("MultiError", func() {
	Describe("Error", func() {
		Context("when reasons are given", func() {
			It("returns each reason as bullet points", func() {
				err := NewMultiError(errors.New("reason 1"), errors.New("reason 2"))
				Expect(err.Error()).To(Equal("reason 1\nreason 2"))
			})
		})

		Context("when no reasons are given", func() {
			It("returns empty string", func() {
				err := NewMultiError()
				Expect(err.Error()).To(Equal(""))
			})
		})
	})
})
