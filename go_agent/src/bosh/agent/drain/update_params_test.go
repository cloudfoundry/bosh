package drain_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshas "bosh/agent/applier/applyspec"
	. "bosh/agent/drain"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("update packages", func() {

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
}
