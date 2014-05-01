package assert

import (
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"strings"
)

func MatchesJSONMap(t assert.TestingT, object interface{}, expectedJSON map[string]interface{}) {
	expectedBytes, err := json.Marshal(expectedJSON)
	assert.NoError(t, err)

	MatchesJSONBytes(t, object, expectedBytes)
}

func MatchesJSONString(t assert.TestingT, object interface{}, expectedJSON string) {
	MatchesJSONBytes(t, object, []byte(expectedJSON))
}

func MatchesJSONBytes(t assert.TestingT, object interface{}, expectedJSON []byte) {
	objectBytes, err := json.Marshal(object)
	assert.NoError(t, err)

	// Use strings instead of []byte for reasonable error message
	assert.Equal(t, string(expectedJSON), string(objectBytes))
}

func LacksJSONKey(t assert.TestingT, object interface{}, key string) {
	objectBytes, err := json.Marshal(object)
	assert.NoError(t, err)

	objectAsMap := make(map[string]interface{})

	err = json.Unmarshal(objectBytes, &objectAsMap)
	assert.NoError(t, err)

	_, found := objectAsMap[key]

	objectKeys := make([]string, len(objectAsMap))
	i := 0
	for k := range objectAsMap {
		objectKeys[i] = k
		i++
	}

	assert.False(t, found, `Expected object with keys "%s" to not have key "%s"`, strings.Join(objectKeys, ", "), key)
}
