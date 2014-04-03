package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakeappl "bosh/agent/applier/fakes"
	boshassert "bosh/assert"
)

func init() {
	Describe("concreteApplier", func() {
		var (
			applier     *fakeappl.FakeApplier
			specService *fakeas.FakeV1Service
			action      ApplyAction
		)

		BeforeEach(func() {
			applier = fakeappl.NewFakeApplier()
			specService = fakeas.NewFakeV1Service()
			action = NewApply(applier, specService)
		})

		It("apply should be asynchronous", func() {
			Expect(action.IsAsynchronous()).To(BeTrue())
		})

		It("is not persistent", func() {
			Expect(action.IsPersistent()).To(BeFalse())
		})

		Describe("Run", func() {
			It("apply returns applied", func() {
				applySpec := boshas.V1ApplySpec{
					ConfigurationHash: "fake-config-hash",
				}

				value, err := action.Run(applySpec)
				Expect(err).ToNot(HaveOccurred())
				boshassert.MatchesJsonString(GinkgoT(), value, `"applied"`)
			})

			It("saves the first argument to spec json", func() {
				applySpec := boshas.V1ApplySpec{
					ConfigurationHash: "fake-config-hash",
				}

				_, err := action.Run(applySpec)
				Expect(err).ToNot(HaveOccurred())
				Expect(specService.Spec).To(Equal(applySpec))
			})

			It("skips applier when apply spec does not have configuration hash", func() {
				applySpec := boshas.V1ApplySpec{
					JobSpec: boshas.JobSpec{
						Template: "fake-job-template",
					},
				}

				_, err := action.Run(applySpec)
				Expect(err).ToNot(HaveOccurred())
				Expect(applier.Applied).To(BeFalse())
			})

			It("runs applier with apply spec when apply spec has configuration hash", func() {
				expectedApplySpec := boshas.V1ApplySpec{
					JobSpec: boshas.JobSpec{
						Template: "fake-job-template",
					},
					ConfigurationHash: "fake-config-hash",
				}

				_, err := action.Run(expectedApplySpec)
				Expect(err).ToNot(HaveOccurred())
				Expect(applier.Applied).To(BeTrue())
				Expect(applier.ApplyApplySpec).To(Equal(expectedApplySpec))
			})

			It("errs when applier fails", func() {
				applier.ApplyError = errors.New("fake-apply-error")

				_, err := action.Run(boshas.V1ApplySpec{ConfigurationHash: "fake-config-hash"})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-apply-error"))
			})
		})
	})
}
