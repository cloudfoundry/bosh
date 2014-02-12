package handler_test

import (
	boshassert "bosh/assert"
	. "bosh/handler"
	. "github.com/onsi/ginkgo"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("json with value", func() {

			resp := NewValueResponse("some value")
			boshassert.MatchesJsonString(GinkgoT(), resp, `{"value":"some value"}`)
		})
		It("json with exception", func() {

			resp := NewExceptionResponse("oops!")
			boshassert.MatchesJsonString(GinkgoT(), resp, `{"exception":{"message":"oops!"}}`)
		})
	})
}
