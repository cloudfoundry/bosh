package app_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/app"

	boshplatform "bosh/platform"
	fakesys "bosh/system/fakes"
)

var _ = Describe("LoadConfigFromPath", func() {
	var (
		fs *fakesys.FakeFileSystem
	)

	BeforeEach(func() {
		fs = fakesys.NewFakeFileSystem()
	})

	It("returns populates config", func() {
		fs.WriteFileString("/fake-config.conf", `{
			"Platform": {
				"Linux": {
					"UseDefaultTmpDir": true,
					"UsePreformattedPersistentDisk": true,
					"BindMountPersistentDisk": true
				}
			}
		}`)

		config, err := LoadConfigFromPath(fs, "/fake-config.conf")
		Expect(err).ToNot(HaveOccurred())
		Expect(config).To(Equal(Config{
			Platform: boshplatform.ProviderOptions{
				Linux: boshplatform.LinuxOptions{
					UseDefaultTmpDir:              true,
					UsePreformattedPersistentDisk: true,
					BindMountPersistentDisk:       true,
				},
			},
		}))
	})

	It("returns empty config if path is empty", func() {
		config, err := LoadConfigFromPath(fs, "")
		Expect(err).ToNot(HaveOccurred())
		Expect(config).To(Equal(Config{}))
	})

	It("returns error if file is not found", func() {
		_, err := LoadConfigFromPath(fs, "/something_not_exist")
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(ContainSubstring("not found"))
	})

	It("returns error if file cannot be parsed", func() {
		fs.WriteFileString("/fake-config.conf", `fake-invalid-json`)

		_, err := LoadConfigFromPath(fs, "/fake-config.conf")
		Expect(err).To(HaveOccurred())
		Expect(err.Error()).To(ContainSubstring("invalid character"))
	})
})
