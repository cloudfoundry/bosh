package applyspec

import (
	boshbc "bosh/agent/applyspec/bundlecollection"
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestHandlerProviderGetReturnsConcreteProvider(t *testing.T) {
	fs := &fakesys.FakeFileSystem{}

	expectedApplier := NewConcreteApplier(
		boshbc.NewFileBundleCollection("jobs", "/var/vcap", fs),
		boshbc.NewFileBundleCollection("packages", "/var/vcap", fs),
	)

	provider := NewApplierProvider(fs)
	applier := provider.Get()
	assert.Equal(t, expectedApplier, applier)
}
