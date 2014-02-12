package action_test

import (
	. "bosh/agent/action"
	boshmodels "bosh/agent/applier/models"
	boshcomp "bosh/agent/compiler"
	fakecomp "bosh/agent/compiler/fakes"
	boshassert "bosh/assert"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

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

func buildCompilePackageAction() (compiler *fakecomp.FakeCompiler, action CompilePackageAction) {
	compiler = fakecomp.NewFakeCompiler()
	action = NewCompilePackage(compiler)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("compile package should be asynchronous", func() {
			_, action := buildCompilePackageAction()
			assert.True(GinkgoT(), action.IsAsynchronous())
		})
		It("compile package compiles the package abd returns blob id", func() {

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
			expectedDeps := []boshmodels.Package{
				{
					Name:    "first_dep",
					Version: "first_dep_version",
					Source: boshmodels.Source{
						Sha1:        "first_dep_sha1",
						BlobstoreId: "first_dep_blobstore_id",
					},
				},
				{
					Name:    "sec_dep",
					Version: "sec_dep_version",
					Source: boshmodels.Source{
						Sha1:        "sec_dep_sha1",
						BlobstoreId: "sec_dep_blobstore_id",
					},
				},
			}

			val, err := action.Run(blobId, sha1, name, version, deps)

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), expectedPkg, compiler.CompilePkg)

			assert.Equal(GinkgoT(), expectedDeps, compiler.CompileDeps)

			boshassert.MatchesJsonMap(GinkgoT(), val, expectedJson)
		})
		It("compile package errs when compile fails", func() {

			compiler, action := buildCompilePackageAction()
			compiler.CompileErr = errors.New("Oops")

			blobId, sha1, name, version, deps := getCompileActionArguments()

			_, err := action.Run(blobId, sha1, name, version, deps)

			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), compiler.CompileErr.Error())
		})
	})
}
