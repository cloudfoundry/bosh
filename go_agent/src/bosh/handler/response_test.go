package handler

import (
	boshassert "bosh/assert"
	"testing"
)

func TestJsonWithValue(t *testing.T) {
	resp := NewValueResponse("some value")
	boshassert.MatchesJsonString(t, resp, `{"value":"some value"}`)
}

func TestJsonWithException(t *testing.T) {
	resp := NewExceptionResponse("oops!")
	boshassert.MatchesJsonString(t, resp, `{"exception":{"message":"oops!"}}`)
}
