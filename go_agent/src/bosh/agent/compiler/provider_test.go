package compiler

import (
	fakeblobstore "bosh/blobstore/fakes"
	fakeplatform "bosh/platform/fakes"
	boshdirs "bosh/settings/directories"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGet(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	blobstore := fakeblobstore.NewFakeBlobstore()
	dirProvider := boshdirs.NewDirectoriesProvider("/fake-dir")

	compiler := NewCompilerProvider(platform, blobstore, dirProvider).Get()

	expectedCompiler := newConcreteCompiler(
		platform.GetCompressor(),
		blobstore,
		platform.GetFs(),
		platform.GetRunner(),
		dirProvider,
	)

	assert.Equal(t, expectedCompiler, compiler)
}
