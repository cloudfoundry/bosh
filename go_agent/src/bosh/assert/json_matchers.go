package assert

import (
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"strings"
)

func MatchesJsonMap(t assert.TestingT, object interface{}, expectedJson map[string]interface{}) {
	expectedBytes, err := json.Marshal(expectedJson)
	assert.NoError(t, err)

	MatchesJsonBytes(t, object, expectedBytes)
}

func MatchesJsonString(t assert.TestingT, object interface{}, expectedJson string) {
	MatchesJsonBytes(t, object, []byte(expectedJson))
}

func MatchesJsonBytes(t assert.TestingT, object interface{}, expectedJson []byte) {
	objectBytes, err := json.Marshal(object)
	assert.NoError(t, err)

	// Use strings instead of []byte for reasonable error message
	assert.Equal(t, string(expectedJson), string(objectBytes))
}

func LacksJsonKey(t assert.TestingT, object interface{}, key string) {
	objectBytes, err := json.Marshal(object)
	assert.NoError(t, err)

	objectAsMap := make(map[string]interface{})

	err = json.Unmarshal(objectBytes, &objectAsMap)
	assert.NoError(t, err)

	_, found := objectAsMap[key]

	objectKeys := make([]string, len(objectAsMap))
	i := 0
	for k, _ := range objectAsMap {
		objectKeys[i] = k
		i++
	}

	assert.False(t, found, `Expected object with keys "%s" to not have key "%s"`, strings.Join(objectKeys, ", "), key)
}
