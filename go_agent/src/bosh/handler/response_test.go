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
			boshassert.MatchesJSONString(GinkgoT(), resp, `{"value":"some value"}`)
		})
		It("json with exception", func() {

			resp := NewExceptionResponse("oops!")
			boshassert.MatchesJSONString(GinkgoT(), resp, `{"exception":{"message":"oops!"}}`)
		})
	})
}
