package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	boshmodels "bosh/agent/applier/models"
	boshcomp "bosh/agent/compiler"
	fakecomp "bosh/agent/compiler/fakes"
	boshassert "bosh/assert"
)

func getCompileActionArguments() (blobID, sha1, name, version string, deps boshcomp.Dependencies) {
	blobID = "blobstore_id"
	sha1 = "sha1"
	name = "pkg_name"
	version = "pkg_version"
	deps = boshcomp.Dependencies{
		"first_dep": boshcomp.Package{
			BlobstoreID: "first_dep_blobstore_id",
			Name:        "first_dep",
			Sha1:        "first_dep_sha1",
			Version:     "first_dep_version",
		},
		"sec_dep": boshcomp.Package{
			BlobstoreID: "sec_dep_blobstore_id",
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
			Expect(action.IsAsynchronous()).To(BeTrue())
		})

		It("is not persistent", func() {
			_, action := buildCompilePackageAction()
			Expect(action.IsPersistent()).To(BeFalse())
		})

		It("compile package compiles the package abd returns blob id", func() {

			compiler, action := buildCompilePackageAction()
			compiler.CompileBlobID = "my-blob-id"
			compiler.CompileSha1 = "some sha1"

			blobID, sha1, name, version, deps := getCompileActionArguments()

			expectedPkg := boshcomp.Package{
				BlobstoreID: blobID,
				Sha1:        sha1,
				Name:        name,
				Version:     version,
			}
			expectedJSON := map[string]interface{}{
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
						BlobstoreID: "first_dep_blobstore_id",
					},
				},
				{
					Name:    "sec_dep",
					Version: "sec_dep_version",
					Source: boshmodels.Source{
						Sha1:        "sec_dep_sha1",
						BlobstoreID: "sec_dep_blobstore_id",
					},
				},
			}

			val, err := action.Run(blobID, sha1, name, version, deps)

			Expect(err).ToNot(HaveOccurred())
			Expect(expectedPkg).To(Equal(compiler.CompilePkg))

			Expect(expectedDeps).To(Equal(compiler.CompileDeps))

			boshassert.MatchesJSONMap(GinkgoT(), val, expectedJSON)
		})
		It("compile package errs when compile fails", func() {

			compiler, action := buildCompilePackageAction()
			compiler.CompileErr = errors.New("Oops")

			blobID, sha1, name, version, deps := getCompileActionArguments()

			_, err := action.Run(blobID, sha1, name, version, deps)

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring(compiler.CompileErr.Error()))
		})
	})
}
