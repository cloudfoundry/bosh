package handler_test

import (
	"errors"

	. "github.com/onsi/ginkgo"

	boshassert "bosh/assert"
	. "bosh/handler"
)

type testShortError struct {
	fullMsg   string
	shortMsgs []string
}

func (e testShortError) Error() string { return e.fullMsg }

func (e *testShortError) ShortError() string {
	msg := e.shortMsgs[0]
	e.shortMsgs = e.shortMsgs[1:]
	return msg
}

var _ = Describe("NewValueResponse", func() {
	It("can be serialized to JSON", func() {
		resp := NewValueResponse("fake-value")
		boshassert.MatchesJSONString(GinkgoT(), resp, `{"value":"fake-value"}`)
	})

	It("shortening does not change the response", func() {
		resp := NewValueResponse("fake-value")
		boshassert.MatchesJSONString(GinkgoT(), resp.Shorten(), `{"value":"fake-value"}`)
	})
})

var _ = Describe("NewExceptionResponse", func() {
	Context("with error that can be shortened", func() {
		var err error

		BeforeEach(func() {
			err = &testShortError{
				fullMsg:   "fake-full-msg",
				shortMsgs: []string{"fake-short-msg1", "fake-short-msg2"},
			}
		})

		It("can be serialized to JSON", func() {
			resp := NewExceptionResponse(err)
			boshassert.MatchesJSONString(GinkgoT(), resp, `{"exception":{"message":"fake-full-msg"}}`)
		})

		It("can be shorted and then serialized to JSON", func() {
			resp := NewExceptionResponse(err)
			boshassert.MatchesJSONString(
				GinkgoT(),
				resp.Shorten(),
				`{"exception":{"message":"fake-short-msg1"}}`,
			)
		})

		It("can be shorted multiple times and then serialized to JSON", func() {
			resp := NewExceptionResponse(err)
			boshassert.MatchesJSONString(
				GinkgoT(),
				resp.Shorten().Shorten(),
				`{"exception":{"message":"fake-short-msg2"}}`,
			)
		})
	})

	Context("with error that cannot be shortened", func() {
		err := errors.New("fake-msg")

		It("can be serialized to JSON", func() {
			resp := NewExceptionResponse(err)
			boshassert.MatchesJSONString(GinkgoT(), resp, `{"exception":{"message":"fake-msg"}}`)
		})

		It("shortening does not change the response", func() {
			resp := NewExceptionResponse(err)
			boshassert.MatchesJSONString(GinkgoT(), resp.Shorten(), `{"exception":{"message":"fake-msg"}}`)
		})

		It("shortening multiple times does not change the response", func() {
			resp := NewExceptionResponse(err)
			boshassert.MatchesJSONString(
				GinkgoT(),
				resp.Shorten().Shorten(),
				`{"exception":{"message":"fake-msg"}}`,
			)
		})
	})
})
