package bundlecollection_test

import (
	. "bosh/agent/applier/bundlecollection"
	fakesys "bosh/system/fakes"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

type testBundle struct {
	Name    string
	Version string
}

func (s testBundle) BundleName() string    { return s.Name }
func (s testBundle) BundleVersion() string { return s.Version }

var _ = Describe("FileBundleCollection", func() {
	var (
		fs                   *fakesys.FakeFileSystem
		fileBundleCollection FileBundleCollection
	)

	BeforeEach(func() {
		fs = &fakesys.FakeFileSystem{}
	})

	JustBeforeEach(func() {
		fileBundleCollection = NewFileBundleCollection("/fake-collection-path/data", "/fake-collection-path", "fake-collection-name", fs)

	})

	Describe("#Get", func() {
		It("returns the file bundle", func() {
			bundleDefinition := testBundle{
				Name:    "bundle-name",
				Version: "bundle-version",
			}

			fileBundle, err := fileBundleCollection.Get(bundleDefinition)
			Expect(err).NotTo(HaveOccurred())

			expectedBundle := NewFileBundle(
				"/fake-collection-path/data/fake-collection-name/bundle-name/bundle-version",
				"/fake-collection-path/fake-collection-name/bundle-name",
				fs,
			)

			Expect(fileBundle).To(Equal(expectedBundle))
		})
		Context("when definition is missing name", func() {
			It("errors", func() {
				bundleDefinition := testBundle{
					Version: "bundle-version",
				}

				_, err := fileBundleCollection.Get(bundleDefinition)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("missing bundle name"))
			})
		})

		Context("when definition is missing version", func() {
			It("errors", func() {
				bundleDefinition := testBundle{
					Name: "bundle-name",
				}

				_, err := fileBundleCollection.Get(bundleDefinition)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("missing bundle version"))
			})
		})
	})
})
