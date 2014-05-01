package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	boshas "bosh/agent/applier/applyspec"
	fakeappl "bosh/agent/applier/fakes"
)

var _ = Describe("PrepareAction", func() {
	var (
		applier *fakeappl.FakeApplier
		action  PrepareAction
	)

	BeforeEach(func() {
		applier = fakeappl.NewFakeApplier()
		action = NewPrepare(applier)
	})

	It("is asynchronous", func() {
		Expect(action.IsAsynchronous()).To(BeTrue())
	})

	It("is not persistent", func() {
		Expect(action.IsPersistent()).To(BeFalse())
	})

	Describe("Run", func() {
		desiredApplySpec := boshas.V1ApplySpec{ConfigurationHash: "fake-desired-config-hash"}

		It("runs applier to prepare vm for future configuration with desired apply spec", func() {
			_, err := action.Run(desiredApplySpec)
			Expect(err).ToNot(HaveOccurred())
			Expect(applier.Prepared).To(BeTrue())
			Expect(applier.PrepareDesiredApplySpec).To(Equal(desiredApplySpec))
		})

		Context("when applier succeeds preparing vm", func() {
			It("returns 'applied' after setting desired spec as current spec", func() {
				value, err := action.Run(desiredApplySpec)
				Expect(err).ToNot(HaveOccurred())
				Expect(value).To(Equal("prepared"))
			})
		})

		Context("when applier fails preparing vm", func() {
			It("returns error", func() {
				applier.PrepareError = errors.New("fake-prepare-error")

				_, err := action.Run(desiredApplySpec)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-prepare-error"))
			})
		})
	})
})
