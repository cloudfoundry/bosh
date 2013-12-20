package compiler

import (
	fakeblobstore "bosh/blobstore/fakes"
	fakeplatform "bosh/platform/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGet(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()
	blobstore := fakeblobstore.NewFakeBlobstore()

	compiler := NewCompilerProvider(platform, blobstore).Get()
	expectedCompiler := newConcreteCompiler(
		platform.GetCompressor(),
		blobstore,
		platform.GetFs(),
		platform.GetRunner(),
	)

	assert.Equal(t, expectedCompiler, compiler)
}
