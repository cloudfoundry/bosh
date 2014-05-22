package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	boshmodels "bosh/agent/applier/models"
	boshcomp "bosh/agent/compiler"
	fakecomp "bosh/agent/compiler/fakes"
)

func getCompileActionArguments() (blobID, sha1, name, version string, deps boshcomp.Dependencies) {
	blobID = "fake-blobstore-id"
	sha1 = "fake-sha1"
	name = "fake-package-name"
	version = "fake-package-version"
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

var _ = Describe("CompilePackageAction", func() {
	var (
		compiler *fakecomp.FakeCompiler
		action   CompilePackageAction
	)

	BeforeEach(func() {
		compiler = fakecomp.NewFakeCompiler()
		action = NewCompilePackage(compiler)
	})

	It("is asynchronous", func() {
		Expect(action.IsAsynchronous()).To(BeTrue())
	})

	It("is not persistent", func() {
		Expect(action.IsPersistent()).To(BeFalse())
	})

	Describe("Run", func() {
		It("compile package compiles the package abd returns blob id", func() {
			compiler.CompileBlobID = "my-blob-id"
			compiler.CompileSha1 = "some sha1"

			expectedPkg := boshcomp.Package{
				BlobstoreID: "fake-blobstore-id",
				Sha1:        "fake-sha1",
				Name:        "fake-package-name",
				Version:     "fake-package-version",
			}

			expectedValue := map[string]interface{}{
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

			value, err := action.Run(getCompileActionArguments())
			Expect(err).ToNot(HaveOccurred())
			Expect(value).To(Equal(expectedValue))

			Expect(expectedPkg).To(Equal(compiler.CompilePkg))
			Expect(expectedDeps).To(Equal(compiler.CompileDeps))
		})

		It("returns error when compile fails", func() {
			compiler.CompileErr = errors.New("fake-compile-error")

			_, err := action.Run(getCompileActionArguments())
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-compile-error"))
		})
	})
})
