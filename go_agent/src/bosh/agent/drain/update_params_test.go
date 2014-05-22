package drain_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshas "bosh/agent/applier/applyspec"
	. "bosh/agent/drain"
)

var _ = Describe("updateDrainParams", func() {
	Describe("UpdatedPackages", func() {
		It("returns list of packages that changed or got added", func() {
			oldPkgs := map[string]boshas.PackageSpec{
				"foo": boshas.PackageSpec{
					Name: "foo",
					Sha1: "foo-sha1-old",
				},
				"bar": boshas.PackageSpec{
					Name: "bar",
					Sha1: "bar-sha1",
				},
			}

			newPkgs := map[string]boshas.PackageSpec{
				"foo": boshas.PackageSpec{
					Name: "foo",
					Sha1: "foo-sha1-new",
				},
				"bar": boshas.PackageSpec{
					Name: "bar",
					Sha1: "bar-sha1",
				},
				"baz": boshas.PackageSpec{
					Name: "baz",
					Sha1: "baz-sha1",
				},
			}

			oldSpec := boshas.V1ApplySpec{
				PackageSpecs: oldPkgs,
			}

			newSpec := boshas.V1ApplySpec{
				PackageSpecs: newPkgs,
			}

			params := NewUpdateDrainParams(oldSpec, newSpec)

			Expect(params.UpdatedPackages()).To(Equal([]string{"foo", "baz"}))
		})
	})

	Describe("JobState", func() {
		It("returns JSON serialized current spec that only includes persistent disk", func() {
			oldSpec := boshas.V1ApplySpec{PersistentDisk: 200}
			newSpec := boshas.V1ApplySpec{PersistentDisk: 301}
			params := NewUpdateDrainParams(oldSpec, newSpec)

			state, err := params.JobState()
			Expect(err).ToNot(HaveOccurred())
			Expect(state).To(Equal(`{"persistent_disk":200}`))
		})
	})

	Describe("JobNextState", func() {
		It("returns JSON serialized future spec that only includes persistent disk", func() {
			oldSpec := boshas.V1ApplySpec{PersistentDisk: 200}
			newSpec := boshas.V1ApplySpec{PersistentDisk: 301}
			params := NewUpdateDrainParams(oldSpec, newSpec)

			state, err := params.JobNextState()
			Expect(err).ToNot(HaveOccurred())
			Expect(state).To(Equal(`{"persistent_disk":301}`))
		})
	})
})
