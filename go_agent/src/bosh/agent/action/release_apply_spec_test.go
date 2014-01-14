package action

import (
	fakeplatform "bosh/platform/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestRun(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	_, err := platform.GetFs().WriteToFile("/var/vcap/micro/apply_spec.json", "some contents")
	assert.NoError(t, err)
	action := newReleaseApplySpec(platform)

	value, err := action.Run()
	assert.NoError(t, err)

	assert.Equal(t, value, "some contents")
}
