package applier

import (
	bc "bosh/agent/applier/bundlecollection"
	ja "bosh/agent/applier/jobapplier"
	pa "bosh/agent/applier/packageapplier"
	fakeblob "bosh/blobstore/fakes"
	fakemon "bosh/monitor/fakes"
	fakeplatform "bosh/platform/fakes"
	boshdirs "bosh/settings/directories"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestHandlerProviderGetReturnsConcreteProvider(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	blobstore := fakeblob.NewFakeBlobstore()
	monitor := fakemon.NewFakeMonitor()

	expectedPackageApplier := pa.NewConcretePackageApplier(
		bc.NewFileBundleCollection("/fake-base-dir/data", "/fake-base-dir", "packages", platform.GetFs()),
		blobstore,
		platform.GetCompressor(),
	)

	expectedJobApplier := ja.NewRenderedJobApplier(
		bc.NewFileBundleCollection("/fake-base-dir/data", "/fake-base-dir", "jobs", platform.GetFs()),
		blobstore,
		platform.GetCompressor(),
		monitor,
	)
	dirProvider := boshdirs.NewDirectoriesProvider("/fake-base-dir")
	expectedApplier := NewConcreteApplier(
		expectedJobApplier,
		expectedPackageApplier,
		platform,
		monitor,
		dirProvider,
	)

	provider := NewApplierProvider(platform, blobstore, monitor, dirProvider)
	applier := provider.Get()
	assert.Equal(t, expectedApplier, applier)
}
