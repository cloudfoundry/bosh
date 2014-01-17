package action

import (
	fakeplatform "bosh/platform/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestRun(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	_, err := platform.GetFs().WriteToFile("/var/vcap/micro/apply_spec.json", `{"json":["objects"]}`)
	assert.NoError(t, err)
	action := newReleaseApplySpec(platform)

	value, err := action.Run()
	assert.NoError(t, err)

	assert.Equal(t, value, map[string]interface{}{"json": []interface{}{"objects"}})
}
