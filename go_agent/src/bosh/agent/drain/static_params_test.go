package drain_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshas "bosh/agent/applier/applyspec"
	. "bosh/agent/drain"
)

var _ = Describe("NewShutdownDrainParams", func() {
	oldSpec := boshas.V1ApplySpec{PersistentDisk: 200}
	newSpec := boshas.V1ApplySpec{PersistentDisk: 301}

	Describe("JobState", func() {
		It("returns JSON serialized current spec that only includes persistent disk", func() {
			state, err := NewShutdownDrainParams(oldSpec, &newSpec).JobState()
			Expect(err).ToNot(HaveOccurred())
			Expect(state).To(Equal(`{"persistent_disk":200}`))
		})
	})

	Describe("JobNextState", func() {
		It("returns JSON serialized future spec that only includes persistent disk", func() {
			state, err := NewShutdownDrainParams(oldSpec, &newSpec).JobNextState()
			Expect(err).ToNot(HaveOccurred())
			Expect(state).To(Equal(`{"persistent_disk":301}`))
		})

		It("returns empty string if next state is not available", func() {
			state, err := NewShutdownDrainParams(oldSpec, nil).JobNextState()
			Expect(err).ToNot(HaveOccurred())
			Expect(state).To(Equal(""))
		})
	})
})

var _ = Describe("NewStatusDrainParams", func() {
	oldSpec := boshas.V1ApplySpec{PersistentDisk: 200}
	newSpec := boshas.V1ApplySpec{PersistentDisk: 301}

	Describe("JobState", func() {
		It("returns JSON serialized current spec that only includes persistent disk", func() {
			state, err := NewStatusDrainParams(oldSpec, &newSpec).JobState()
			Expect(err).ToNot(HaveOccurred())
			Expect(state).To(Equal(`{"persistent_disk":200}`))
		})
	})

	Describe("JobNextState", func() {
		It("returns JSON serialized future spec that only includes persistent disk", func() {
			state, err := NewStatusDrainParams(oldSpec, &newSpec).JobNextState()
			Expect(err).ToNot(HaveOccurred())
			Expect(state).To(Equal(`{"persistent_disk":301}`))
		})

		It("returns empty string if next state is not available", func() {
			state, err := NewStatusDrainParams(oldSpec, nil).JobNextState()
			Expect(err).ToNot(HaveOccurred())
			Expect(state).To(Equal(""))
		})
	})
})
