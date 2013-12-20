package action

import (
	boshcomp "bosh/agent/compiler"
	fakecomp "bosh/agent/compiler/fakes"
	boshassert "bosh/assert"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestCompilePackageShouldBeAsynchronous(t *testing.T) {
	_, action := buildCompilePackageAction()
	assert.True(t, action.IsAsynchronous())
}

func TestCompilePackageCompilesThePackageAbdReturnsBlobId(t *testing.T) {
	compiler, action := buildCompilePackageAction()
	compiler.CompileBlobId = "my-blob-id"
	compiler.CompileSha1 = "some sha1"

	blobId, sha1, name, version, deps := getCompileActionArguments()

	expectedPkg := boshcomp.Package{
		BlobstoreId: blobId,
		Sha1:        sha1,
		Name:        name,
		Version:     version,
	}
	expectedJson := map[string]interface{}{
		"result": map[string]string{
			"blobstore_id": "my-blob-id",
			"sha1":         "some sha1",
		},
	}

	val, err := action.Run(blobId, sha1, name, version, deps)

	assert.NoError(t, err)
	assert.Equal(t, expectedPkg, compiler.CompilePkg)
	assert.Equal(t, deps, compiler.CompileDeps)
	boshassert.MatchesJsonMap(t, val, expectedJson)
}

func TestCompilePackageErrsWhenCompileFails(t *testing.T) {
	compiler, action := buildCompilePackageAction()
	compiler.CompileErr = errors.New("Oops")

	blobId, sha1, name, version, deps := getCompileActionArguments()

	_, err := action.Run(blobId, sha1, name, version, deps)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), compiler.CompileErr.Error())
}

func getCompileActionArguments() (blobId, sha1, name, version string, deps boshcomp.Dependencies) {
	blobId = "blobstore_id"
	sha1 = "sha1"
	name = "pkg_name"
	version = "pkg_version"
	deps = boshcomp.Dependencies{
		"first_dep": boshcomp.Package{
			BlobstoreId: "first_dep_blobstore_id",
			Name:        "first_dep",
			Sha1:        "first_dep_sha1",
			Version:     "first_dep_version",
		},
		"sec_dep": boshcomp.Package{
			BlobstoreId: "sec_dep_blobstore_id",
			Name:        "sec_dep",
			Sha1:        "sec_dep_sha1",
			Version:     "sec_dep_version",
		},
	}
	return
}

func buildCompilePackageAction() (compiler *fakecomp.FakeCompiler, action compilePackageAction) {
	compiler = fakecomp.NewFakeCompiler()
	action = newCompilePackage(compiler)
	return
}
