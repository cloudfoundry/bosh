package errors_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/errors"
)

type testShortError struct {
	fullMsg  string
	shortMsg string
}

func (e testShortError) Error() string       { return e.fullMsg }
func (e *testShortError) ShortError() string { return e.shortMsg }

var _ = Describe("New", func() {
	It("constructs an error", func() {
		err := New("fake-message")
		Expect(err).To(MatchError("fake-message"))
	})

	It("constructs a formatted error", func() {
		err := New("fake-message: %s", "fake-details")
		Expect(err).To(MatchError("fake-message: fake-details"))
	})
})

var _ = Describe("WrapError", func() {
	It("constructs a ShortenableError", func() {
		cause := New("fake-cause-message")

		err := WrapError(cause, "fake-message")
		Expect(err).To(MatchError("fake-message: fake-cause-message"))

		typedErr := err.(ShortenableError)
		Expect(typedErr.ShortError()).To(Equal("fake-message: fake-cause-message"))
	})

	It("constructs a formatted ShortenableError", func() {
		cause := New("fake-cause-message")

		err := WrapError(cause, "fake-message: %s", "fake-details")
		Expect(err).To(MatchError("fake-message: fake-details: fake-cause-message"))

		typedErr := err.(ShortenableError)
		Expect(typedErr.ShortError()).To(Equal("fake-message: fake-details: fake-cause-message"))
	})
})

var _ = Describe("WrapComplexError", func() {
	It("constructs a ShortenableError", func() {
		cause := New("fake-cause-message")
		delegate := New("fake-message")

		err := WrapComplexError(cause, delegate)
		Expect(err).To(MatchError("fake-message: fake-cause-message"))

		typedErr := err.(ShortenableError)
		Expect(typedErr.ShortError()).To(Equal("fake-message: fake-cause-message"))
	})

	It("allows chaining", func() {
		causeCause := New("fake-cause-cause")
		causeDelegate := New("fake-cause-delegate")
		cause := WrapComplexError(causeCause, causeDelegate)

		delegateCause := New("fake-delegate-cause")
		delegateDelegate := New("fake-delegate-delegate")
		delegate := WrapComplexError(delegateCause, delegateDelegate)

		err := WrapComplexError(cause, delegate)
		Expect(err).To(MatchError(
			"fake-delegate-delegate: fake-delegate-cause: fake-cause-delegate: fake-cause-cause"))

		typedErr := err.(ShortenableError)
		Expect(typedErr.ShortError()).To(Equal(
			"fake-delegate-delegate: fake-delegate-cause: fake-cause-delegate: fake-cause-cause"))
	})

	It("shortens errors that are shortenable", func() {
		cause := &testShortError{fullMsg: "cause-full", shortMsg: "cause-short1"}
		delegate := &testShortError{fullMsg: "delegate-full", shortMsg: "delegate-short1"}

		err := WrapComplexError(cause, delegate)
		Expect(err).To(MatchError("delegate-full: cause-full"))

		typedErr := err.(ShortenableError)
		Expect(typedErr.ShortError()).To(Equal("delegate-short1: cause-short1"))
	})
})
