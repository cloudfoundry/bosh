package applier

import (
	bc "bosh/agent/applier/bundlecollection"
	ja "bosh/agent/applier/jobapplier"
	pa "bosh/agent/applier/packageapplier"
	fakeblob "bosh/blobstore/fakes"
	fakejobsuper "bosh/jobsupervisor/fakes"
	fakeplatform "bosh/platform/fakes"
	boshdirs "bosh/settings/directories"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestHandlerProviderGetReturnsConcreteProvider(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	blobstore := fakeblob.NewFakeBlobstore()
	jobSupervisor := fakejobsuper.NewFakeJobSupervisor()

	expectedPackageApplier := pa.NewConcretePackageApplier(
		bc.NewFileBundleCollection("/fake-base-dir/data", "/fake-base-dir", "packages", platform.GetFs()),
		blobstore,
		platform.GetCompressor(),
	)

	expectedJobApplier := ja.NewRenderedJobApplier(
		bc.NewFileBundleCollection("/fake-base-dir/data", "/fake-base-dir", "jobs", platform.GetFs()),
		blobstore,
		platform.GetCompressor(),
		jobSupervisor,
	)
	dirProvider := boshdirs.NewDirectoriesProvider("/fake-base-dir")
	expectedApplier := NewConcreteApplier(
		expectedJobApplier,
		expectedPackageApplier,
		platform,
		jobSupervisor,
		dirProvider,
	)

	provider := NewApplierProvider(platform, blobstore, jobSupervisor, dirProvider)
	applier := provider.Get()
	assert.Equal(t, expectedApplier, applier)
}
