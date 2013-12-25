package drain

import (
	boshas "bosh/agent/applier/applyspec"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestUpdatePackages(t *testing.T) {
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

	updatedPkgs := params.UpdatedPackages()
	assert.Equal(t, []string{"foo", "baz"}, updatedPkgs)
}
