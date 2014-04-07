package bundlecollection_test

import (
	"errors"
	"os"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/applier/bundlecollection"
	boshlog "bosh/logger"
	fakesys "bosh/system/fakes"
)

var _ = Describe("FileBundle", func() {
	var (
		fs          *fakesys.FakeFileSystem
		logger      boshlog.Logger
		installPath string
		enablePath  string
		fileBundle  FileBundle
	)

	BeforeEach(func() {
		fs = &fakesys.FakeFileSystem{}
		installPath = "/install-path"
		enablePath = "/enable-path"
		logger = boshlog.NewLogger(boshlog.LevelNone)
		fileBundle = NewFileBundle(installPath, enablePath, fs, logger)
	})

	Describe("Install", func() {
		It("installs the bundle at the given path with the correct permissions", func() {
			actualFs, path, err := fileBundle.Install()
			Expect(err).NotTo(HaveOccurred())
			Expect(actualFs).To(Equal(fs))
			Expect(path).To(Equal(installPath))

			fileStats := fs.GetFileTestStat(installPath)
			Expect(fileStats).ToNot(BeNil())
			Expect(fileStats.FileType).To(Equal(fakesys.FakeFileType(fakesys.FakeFileTypeDir)))
			Expect(os.FileMode(0755)).To(Equal(fileStats.FileMode))
		})

		It("return error when bundle cannot be installed", func() {
			fs.MkdirAllError = errors.New("fake-mkdirall-error")

			_, _, err := fileBundle.Install()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-mkdirall-error"))
		})

		It("is idempotent", func() {
			fs.MkdirAll("/install-path", os.FileMode(0755))

			actualFs, path, err := fileBundle.Install()
			Expect(err).NotTo(HaveOccurred())
			Expect(actualFs).To(Equal(fs))
			Expect(path).To(Equal(installPath))
		})
	})

	Describe("GetInstallPath", func() {
		It("returns the install path", func() {
			fs.MkdirAll(installPath, os.FileMode(0))

			actualFs, actualInstallPath, err := fileBundle.GetInstallPath()
			Expect(err).NotTo(HaveOccurred())
			Expect(actualFs).To(Equal(fs))
			Expect(actualInstallPath).To(Equal(installPath))
		})

		It("returns error when install directory does not exist", func() {
			_, _, err := fileBundle.GetInstallPath()
			Expect(err).To(HaveOccurred())
		})
	})

	Describe("Enable", func() {
		Context("when bundle is installed", func() {
			BeforeEach(func() {
				_, _, err := fileBundle.Install()
				Expect(err).NotTo(HaveOccurred())
			})

			It("returns the enable path", func() {
				actualFs, actualEnablePath, err := fileBundle.Enable()
				Expect(err).NotTo(HaveOccurred())
				Expect(actualFs).To(Equal(fs))
				Expect(actualEnablePath).To(Equal(enablePath))

				fileStats := fs.GetFileTestStat(enablePath)
				Expect(fileStats).NotTo(BeNil())
				Expect(fileStats.FileType).To(Equal(fakesys.FakeFileType(fakesys.FakeFileTypeSymlink)))
				Expect(installPath).To(Equal(fileStats.SymlinkTarget))

				fileStats = fs.GetFileTestStat("/") // dir holding symlink
				Expect(fileStats).NotTo(BeNil())
				Expect(fileStats.FileType).To(Equal(fakesys.FakeFileType(fakesys.FakeFileTypeDir)))
				Expect(fileStats.FileMode).To(Equal(os.FileMode(0755)))
			})

			It("is idempotent", func() {
				_, _, err := fileBundle.Enable()
				Expect(err).NotTo(HaveOccurred())

				_, _, err = fileBundle.Enable()
				Expect(err).NotTo(HaveOccurred())
			})
		})

		Context("when bundle is not installed", func() {
			It("returns error", func() {
				_, _, err := fileBundle.Enable()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("bundle must be installed"))
			})

			It("does not add symlink", func() {
				_, _, err := fileBundle.Enable()
				Expect(err).To(HaveOccurred())

				fileStats := fs.GetFileTestStat(enablePath)
				Expect(fileStats).To(BeNil())
			})
		})

		Context("when enable dir cannot be created", func() {
			It("returns error", func() {
				_, _, err := fileBundle.Install()
				Expect(err).NotTo(HaveOccurred())
				fs.MkdirAllError = errors.New("fake-mkdirall-error")

				_, _, err = fileBundle.Enable()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-mkdirall-error"))
			})
		})

		Context("when bundle cannot be enabled", func() {
			It("returns error", func() {
				_, _, err := fileBundle.Install()
				Expect(err).NotTo(HaveOccurred())
				fs.SymlinkError = errors.New("fake-symlink-error")

				_, _, err = fileBundle.Enable()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-symlink-error"))
			})
		})
	})

	Describe("Disable", func() {
		It("removes the symlink", func() {
			_, _, err := fileBundle.Install()
			Expect(err).NotTo(HaveOccurred())
			_, _, err = fileBundle.Enable()
			Expect(err).NotTo(HaveOccurred())

			err = fileBundle.Disable()
			Expect(err).NotTo(HaveOccurred())
			Expect(fs.FileExists(enablePath)).To(BeFalse())
		})

		It("is idempotent", func() {
			err := fileBundle.Disable()
			Expect(err).NotTo(HaveOccurred())

			err = fileBundle.Disable()
			Expect(err).NotTo(HaveOccurred())

			Expect(fs.FileExists(enablePath)).To(BeFalse())
		})

		Context("where the symlink is pointing at a different installed version", func() {
			It("does not remove the symlink", func() {
				_, _, err := fileBundle.Install()
				Expect(err).NotTo(HaveOccurred())

				_, _, err = fileBundle.Enable()
				Expect(err).NotTo(HaveOccurred())
				newerInstallPath := "/newer-install-path"
				newerFileBundle := NewFileBundle(newerInstallPath, enablePath, fs, logger)

				_, _, err = newerFileBundle.Install()
				Expect(err).NotTo(HaveOccurred())

				_, _, err = newerFileBundle.Enable()
				Expect(err).NotTo(HaveOccurred())

				err = fileBundle.Disable()
				Expect(err).NotTo(HaveOccurred())

				fileStats := fs.GetFileTestStat(enablePath)
				Expect(fileStats).NotTo(BeNil())
				Expect(fileStats.FileType).To(Equal(fakesys.FakeFileType(fakesys.FakeFileTypeSymlink)))
				Expect(newerInstallPath).To(Equal(fileStats.SymlinkTarget))
			})
		})
	})

	Describe("Uninstall", func() {
		It("removes the files from disk", func() {
			_, _, err := fileBundle.Install()
			Expect(err).NotTo(HaveOccurred())

			err = fileBundle.Uninstall()
			Expect(err).NotTo(HaveOccurred())

			Expect(fs.FileExists(installPath)).To(BeFalse())
		})

		It("is idempotent", func() {
			err := fileBundle.Uninstall()
			Expect(err).NotTo(HaveOccurred())

			err = fileBundle.Uninstall()
			Expect(err).NotTo(HaveOccurred())
		})
	})
})
