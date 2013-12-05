package applyspec

import (
	boshbc "bosh/agent/applyspec/bundlecollection"
	fakeblob "bosh/blobstore/fakes"
	fakeplatform "bosh/platform/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestHandlerProviderGetReturnsConcreteProvider(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	blobstore := fakeblob.NewFakeBlobstore()

	expectedApplier := NewConcreteApplier(
		boshbc.NewFileBundleCollection("jobs", "/var/vcap", platform.GetFs()),
		boshbc.NewFileBundleCollection("packages", "/var/vcap", platform.GetFs()),
		blobstore,
		platform.GetCompressor(),
	)

	provider := NewApplierProvider(platform, blobstore)
	applier := provider.Get()
	assert.Equal(t, expectedApplier, applier)
}
