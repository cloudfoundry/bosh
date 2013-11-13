package mbus

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestJsonWithValue(t *testing.T) {
	resp := Response{Value: "some value"}
	bytes, err := resp.ToJson()

	assert.NoError(t, err)
	assert.Equal(t, `{"value":"some value"}`, string(bytes))
}

func TestJsonWithTaskIdAndState(t *testing.T) {
	resp := Response{
		AgentTaskId: "an id",
		State:       "my task state",
		Value:       "some result",
		Exception:   "oops!",
	}
	bytes, err := resp.ToJson()

	assert.NoError(t, err)
	assert.Equal(t, `{"value":{"agent_task_id":"an id","state":"my task state","value":"some result"},"exception":"oops!"}`, string(bytes))
}

func TestJsonWithException(t *testing.T) {
	resp := Response{Exception: "alert!!"}
	bytes, err := resp.ToJson()

	assert.NoError(t, err)
	assert.Equal(t, `{"exception":"alert!!"}`, string(bytes))
}
