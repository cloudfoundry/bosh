package action_test

import (
	. "bosh/agent/action"
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakeappl "bosh/agent/applier/fakes"
	boshassert "bosh/assert"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildApplyAction() (*fakeappl.FakeApplier, *fakeas.FakeV1Service, ApplyAction) {
	applier := fakeappl.NewFakeApplier()
	specService := fakeas.NewFakeV1Service()
	action := NewApply(applier, specService)
	return applier, specService, action
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("apply should be asynchronous", func() {
			_, _, action := buildApplyAction()
			assert.True(GinkgoT(), action.IsAsynchronous())
		})
		It("apply returns applied", func() {

			_, _, action := buildApplyAction()

			applySpec := boshas.V1ApplySpec{
				JobSpec: boshas.JobSpec{
					Name: "router",
				},
			}

			value, err := action.Run(applySpec)
			assert.NoError(GinkgoT(), err)

			boshassert.MatchesJsonString(GinkgoT(), value, `"applied"`)
		})
		It("apply run saves the first argument to spec json", func() {

			_, specService, action := buildApplyAction()

			applySpec := boshas.V1ApplySpec{
				JobSpec: boshas.JobSpec{
					Name: "router",
				},
			}

			_, err := action.Run(applySpec)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), applySpec, specService.Spec)
		})
		It("apply run skips applier when apply spec does not have configuration hash", func() {

			applier, _, action := buildApplyAction()

			applySpec := boshas.V1ApplySpec{
				JobSpec: boshas.JobSpec{
					Template: "fake-job-template",
				},
			}

			_, err := action.Run(applySpec)
			assert.NoError(GinkgoT(), err)
			assert.False(GinkgoT(), applier.Applied)
		})
		It("apply run runs applier with apply spec when apply spec has configuration hash", func() {

			applier, _, action := buildApplyAction()

			expectedApplySpec := boshas.V1ApplySpec{
				JobSpec: boshas.JobSpec{
					Template: "fake-job-template",
				},
				ConfigurationHash: "fake-config-hash",
			}

			_, err := action.Run(expectedApplySpec)
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), applier.Applied)
			assert.Equal(GinkgoT(), expectedApplySpec, applier.ApplyApplySpec)
		})
		It("apply run errs when applier fails", func() {

			applier, _, action := buildApplyAction()

			applier.ApplyError = errors.New("fake-apply-error")

			_, err := action.Run(boshas.V1ApplySpec{ConfigurationHash: "fake-config-hash"})
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-apply-error")
		})
	})
}
