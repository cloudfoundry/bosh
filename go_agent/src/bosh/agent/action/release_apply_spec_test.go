package action_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	fakeplatform "bosh/platform/fakes"
)

func init() {
	Describe("ReleaseApplySpec", func() {
		var (
			platform *fakeplatform.FakePlatform
			action   ReleaseApplySpecAction
		)

		BeforeEach(func() {
			platform = fakeplatform.NewFakePlatform()
			action = NewReleaseApplySpec(platform)
		})

		It("is synchronous", func() {
			Expect(action.IsAsynchronous()).To(BeFalse())
		})

		It("is not persistent", func() {
			Expect(action.IsPersistent()).To(BeFalse())
		})

		It("run", func() {
			err := platform.GetFs().WriteFileString("/var/vcap/micro/apply_spec.json", `{"json":["objects"]}`)
			Expect(err).ToNot(HaveOccurred())

			value, err := action.Run()
			Expect(err).ToNot(HaveOccurred())

			Expect(value).To(Equal(map[string]interface{}{"json": []interface{}{"objects"}}))
		})
	})
}
