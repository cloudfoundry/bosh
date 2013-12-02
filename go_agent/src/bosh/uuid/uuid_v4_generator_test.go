package uuid

import (
	"github.com/stretchr/testify/assert"
	"regexp"
	"testing"
)

func TestGenerate(t *testing.T) {
	generator := NewGenerator()

	uuid, err := generator.Generate()
	assert.NoError(t, err)

	uuidFormat := "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
	uuidRegexp, _ := regexp.Compile(uuidFormat)
	assert.True(t, uuidRegexp.MatchString(uuid))
}
