package action_test

import (
	. "bosh/agent/action"
	fakeplatform "bosh/platform/fakes"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("run", func() {

			platform := fakeplatform.NewFakePlatform()
			_, err := platform.GetFs().WriteToFile("/var/vcap/micro/apply_spec.json", `{"json":["objects"]}`)
			assert.NoError(GinkgoT(), err)
			action := NewReleaseApplySpec(platform)

			value, err := action.Run()
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), value, map[string]interface{}{"json": []interface{}{"objects"}})
		})
	})
}
