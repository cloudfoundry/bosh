package applier

import (
	bc "bosh/agent/applier/bundlecollection"
	ja "bosh/agent/applier/jobapplier"
	pa "bosh/agent/applier/packageapplier"
	fakeblob "bosh/blobstore/fakes"
	fakemon "bosh/monitor/fakes"
	fakeplatform "bosh/platform/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestHandlerProviderGetReturnsConcreteProvider(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	blobstore := fakeblob.NewFakeBlobstore()
	monitor := fakemon.NewFakeMonitor()

	expectedPackageApplier := pa.NewConcretePackageApplier(
		bc.NewFileBundleCollection("/var/vcap/data", "/var/vcap", "packages", platform.GetFs()),
		blobstore,
		platform.GetCompressor(),
	)

	expectedJobApplier := ja.NewRenderedJobApplier(
		bc.NewFileBundleCollection("/var/vcap/data", "/var/vcap", "jobs", platform.GetFs()),
		blobstore,
		platform.GetCompressor(),
		monitor,
	)

	expectedApplier := NewConcreteApplier(
		expectedJobApplier,
		expectedPackageApplier,
		platform,
		monitor,
	)

	provider := NewApplierProvider(platform, blobstore, monitor, "/var/vcap")
	applier := provider.Get()
	assert.Equal(t, expectedApplier, applier)
}
