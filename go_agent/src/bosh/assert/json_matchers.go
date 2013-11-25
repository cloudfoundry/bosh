package assert

import (
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"testing"
)

func MatchesJsonMap(t *testing.T, object interface{}, expectedJson map[string]interface{}) {
	expectedBytes, err := json.Marshal(expectedJson)
	assert.NoError(t, err)

	MatchesJsonString(t, object, string(expectedBytes))
}

func MatchesJsonString(t *testing.T, object interface{}, expectedJson string) {
	objectBytes, err := json.Marshal(object)
	assert.NoError(t, err)

	assert.Equal(t, expectedJson, string(objectBytes))
}
