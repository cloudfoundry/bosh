package bundlecollection_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/applier/bundlecollection"
	boshlog "bosh/logger"
	fakesys "bosh/system/fakes"
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
		logger               boshlog.Logger
		fileBundleCollection FileBundleCollection
	)

	BeforeEach(func() {
		fs = fakesys.NewFakeFileSystem()
		logger = boshlog.NewLogger(boshlog.LevelNone)
		fileBundleCollection = NewFileBundleCollection(
			"/fake-collection-path/data",
			"/fake-collection-path",
			"fake-collection-name",
			fs,
			logger,
		)
	})

	Describe("Get", func() {
		It("returns the file bundle", func() {
			bundleDefinition := testBundle{
				Name:    "fake-bundle-name",
				Version: "fake-bundle-version",
			}

			fileBundle, err := fileBundleCollection.Get(bundleDefinition)
			Expect(err).NotTo(HaveOccurred())

			expectedBundle := NewFileBundle(
				"/fake-collection-path/data/fake-collection-name/fake-bundle-name/fake-bundle-version",
				"/fake-collection-path/fake-collection-name/fake-bundle-name",
				fs,
				logger,
			)

			Expect(fileBundle).To(Equal(expectedBundle))
		})

		Context("when definition is missing name", func() {
			It("returns error", func() {
				_, err := fileBundleCollection.Get(testBundle{Version: "fake-bundle-version"})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("Missing bundle name"))
			})
		})

		Context("when definition is missing version", func() {
			It("returns error", func() {
				_, err := fileBundleCollection.Get(testBundle{Name: "fake-bundle-name"})
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("Missing bundle version"))
			})
		})
	})

	Describe("List", func() {
		installPath := "/fake-collection-path/data/fake-collection-name"
		enablePath := "/fake-collection-path/fake-collection-name"

		It("returns list of installed bundles", func() {
			fs.SetGlob(installPath+"/*/*", []string{
				installPath + "/fake-bundle-1-name/fake-bundle-1-version-1",
				installPath + "/fake-bundle-1-name/fake-bundle-1-version-2",
				installPath + "/fake-bundle-2-name/fake-bundle-2-version-1",
			})

			bundles, err := fileBundleCollection.List()
			Expect(err).ToNot(HaveOccurred())

			expectedBundles := []Bundle{
				NewFileBundle(
					installPath+"/fake-bundle-1-name/fake-bundle-1-version-1",
					enablePath+"/fake-bundle-1-name",
					fs,
					logger,
				),
				NewFileBundle(
					installPath+"/fake-bundle-1-name/fake-bundle-1-version-2",
					enablePath+"/fake-bundle-1-name",
					fs,
					logger,
				),
				NewFileBundle(
					installPath+"/fake-bundle-2-name/fake-bundle-2-version-1",
					enablePath+"/fake-bundle-2-name",
					fs,
					logger,
				),
			}

			Expect(bundles).To(Equal(expectedBundles))
		})

		It("returns error when glob fails to execute", func() {
			fs.GlobErr = errors.New("fake-glob-error")

			_, err := fileBundleCollection.List()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-glob-error"))
		})

		It("returns error when bundle cannot be built from matched path", func() {
			invalidPaths := []string{
				"",
				"/",
				"before-slash/",
				"/after-slash",
				"no-slash",
			}

			for _, path := range invalidPaths {
				fs.SetGlob(installPath+"/*/*", []string{path})
				_, err := fileBundleCollection.List()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Getting bundle: Missing bundle name"))
			}
		})
	})
})
