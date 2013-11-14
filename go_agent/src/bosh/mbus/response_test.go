package mbus

import (
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestJsonWithValue(t *testing.T) {
	resp := NewValueResponse("some value")
	bytes, err := json.Marshal(resp)

	assert.NoError(t, err)
	assert.Equal(t, `{"value":"some value"}`, string(bytes))
}

func TestJsonWithException(t *testing.T) {
	resp := NewExceptionResponse("oops!")
	bytes, err := json.Marshal(resp)

	assert.NoError(t, err)
	assert.Equal(t, `{"exception":{"message":"oops!"}}`, string(bytes))
}
