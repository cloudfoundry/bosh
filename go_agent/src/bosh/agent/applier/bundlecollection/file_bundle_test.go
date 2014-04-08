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
		sourcePath  string
		installPath string
		enablePath  string
		fileBundle  FileBundle
	)

	BeforeEach(func() {
		fs = fakesys.NewFakeFileSystem()
		installPath = "/install-path"
		enablePath = "/enable-path"
		logger = boshlog.NewLogger(boshlog.LevelNone)
		fileBundle = NewFileBundle(installPath, enablePath, fs, logger)
	})

	createSourcePath := func() string {
		path := "/source-path"
		err := fs.MkdirAll(path, os.ModePerm)
		Expect(err).ToNot(HaveOccurred())
		return path
	}

	BeforeEach(func() {
		sourcePath = createSourcePath()
	})

	Describe("Install", func() {
		It("installs the bundle from source at the given path", func() {
			actualFs, path, err := fileBundle.Install(sourcePath)
			Expect(err).NotTo(HaveOccurred())
			Expect(actualFs).To(Equal(fs))
			Expect(path).To(Equal(installPath))

			Expect(fs.RenameOldPaths[0]).To(Equal(sourcePath))
			Expect(fs.RenameNewPaths[0]).To(Equal(installPath))
		})

		It("returns an error if creation of parent directory fails", func() {
			fs.MkdirAllError = errors.New("fake-mkdir-error")

			_, _, err := fileBundle.Install(sourcePath)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-mkdir-error"))
		})

		It("sets correct permissions on install path", func() {
			fs.Chmod(sourcePath, os.FileMode(0700))

			_, _, err := fileBundle.Install(sourcePath)
			Expect(err).NotTo(HaveOccurred())

			fileStats := fs.GetFileTestStat(installPath)
			Expect(fileStats).ToNot(BeNil())
			Expect(fileStats.FileType).To(Equal(fakesys.FakeFileType(fakesys.FakeFileTypeDir)))
			Expect(fileStats.FileMode).To(Equal(os.FileMode(0755)))
		})

		It("is idempotent", func() {
			actualFs, path, err := fileBundle.Install(sourcePath)
			Expect(err).NotTo(HaveOccurred())
			Expect(actualFs).To(Equal(fs))
			Expect(path).To(Equal(installPath))

			otherSourcePath := createSourcePath()

			actualFs, path, err = fileBundle.Install(otherSourcePath)
			Expect(err).NotTo(HaveOccurred())
			Expect(actualFs).To(Equal(fs))
			Expect(path).To(Equal(installPath))

			Expect(fs.RenameOldPaths[0]).To(Equal(sourcePath))
			Expect(fs.RenameNewPaths[0]).To(Equal(installPath))
		})

		It("returns error when moving source to install path fails", func() {
			fs.RenameError = errors.New("fake-rename-error")

			_, _, err := fileBundle.Install(sourcePath)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-rename-error"))
		})

		It("returns error when it fails to change permissions", func() {
			fs.ChmodErr = errors.New("fake-chmod-error")

			_, _, err := fileBundle.Install(sourcePath)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-chmod-error"))
		})

		It("does not install bundle if it fails to change permissions", func() {
			fs.ChmodErr = errors.New("fake-chmod-error")

			_, _, err := fileBundle.Install(sourcePath)
			Expect(err).To(HaveOccurred())
			Expect(fs.FileExists(installPath)).To(BeFalse())
		})
	})

	Describe("InstallWithoutContents", func() {
		It("installs the bundle at the given path with the correct permissions", func() {
			actualFs, path, err := fileBundle.InstallWithoutContents()
			Expect(err).NotTo(HaveOccurred())
			Expect(actualFs).To(Equal(fs))
			Expect(path).To(Equal(installPath))

			fileStats := fs.GetFileTestStat(installPath)
			Expect(fileStats).ToNot(BeNil())
			Expect(fileStats.FileType).To(Equal(fakesys.FakeFileType(fakesys.FakeFileTypeDir)))
			Expect(fileStats.FileMode).To(Equal(os.FileMode(0755)))
		})

		It("return error when bundle cannot be installed", func() {
			fs.MkdirAllError = errors.New("fake-mkdirall-error")

			_, _, err := fileBundle.InstallWithoutContents()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-mkdirall-error"))
		})

		It("is idempotent", func() {
			_, _, err := fileBundle.InstallWithoutContents()
			Expect(err).NotTo(HaveOccurred())

			actualFs, path, err := fileBundle.InstallWithoutContents()
			Expect(err).NotTo(HaveOccurred())
			Expect(actualFs).To(Equal(fs))
			Expect(path).To(Equal(installPath))
		})
	})

	Describe("GetInstallPath", func() {
		It("returns the install path", func() {
			fs.MkdirAll(installPath, os.ModePerm)

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

	Describe("IsInstalled", func() {
		It("returns true when it is installed", func() {
			_, _, err := fileBundle.Install(sourcePath)
			Expect(err).NotTo(HaveOccurred())

			installed, err := fileBundle.IsInstalled()
			Expect(err).NotTo(HaveOccurred())
			Expect(installed).To(BeTrue())
		})

		It("returns false when it is NOT installed", func() {
			installed, err := fileBundle.IsInstalled()
			Expect(err).NotTo(HaveOccurred())
			Expect(installed).To(BeFalse())
		})

		It("returns an error when check fails", func() {
			// FileExist currently does not return an error
		})
	})

	Describe("Enable", func() {
		Context("when bundle is installed", func() {
			BeforeEach(func() {
				_, _, err := fileBundle.Install(sourcePath)
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
				_, _, err := fileBundle.Install(sourcePath)
				Expect(err).NotTo(HaveOccurred())
				fs.MkdirAllError = errors.New("fake-mkdirall-error")

				_, _, err = fileBundle.Enable()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-mkdirall-error"))
			})
		})

		Context("when bundle cannot be enabled", func() {
			It("returns error", func() {
				_, _, err := fileBundle.Install(sourcePath)
				Expect(err).NotTo(HaveOccurred())
				fs.SymlinkError = errors.New("fake-symlink-error")

				_, _, err = fileBundle.Enable()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-symlink-error"))
			})
		})
	})

	Describe("Disable", func() {
		It("is idempotent", func() {
			err := fileBundle.Disable()
			Expect(err).NotTo(HaveOccurred())

			err = fileBundle.Disable()
			Expect(err).NotTo(HaveOccurred())

			Expect(fs.FileExists(enablePath)).To(BeFalse())
		})

		Context("where the enabled path target is the same installed version", func() {
			BeforeEach(func() {
				_, _, err := fileBundle.Install(sourcePath)
				Expect(err).NotTo(HaveOccurred())

				_, _, err = fileBundle.Enable()
				Expect(err).NotTo(HaveOccurred())
			})

			It("does not return error and removes the symlink", func() {
				err := fileBundle.Disable()
				Expect(err).NotTo(HaveOccurred())
				Expect(fs.FileExists(enablePath)).To(BeFalse())
			})

			It("returns error when bundle cannot be disabled", func() {
				fs.RemoveAllError = errors.New("fake-removeall-error")

				err := fileBundle.Disable()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-removeall-error"))
			})
		})

		Context("where the enabled path target is a different installed version", func() {
			newerInstallPath := "/newer-install-path"

			BeforeEach(func() {
				_, _, err := fileBundle.Install(sourcePath)
				Expect(err).NotTo(HaveOccurred())

				_, _, err = fileBundle.Enable()
				Expect(err).NotTo(HaveOccurred())

				newerFileBundle := NewFileBundle(newerInstallPath, enablePath, fs, logger)

				otherSourcePath := createSourcePath()
				_, _, err = newerFileBundle.Install(otherSourcePath)
				Expect(err).NotTo(HaveOccurred())

				_, _, err = newerFileBundle.Enable()
				Expect(err).NotTo(HaveOccurred())
			})

			It("does not return error and does not remove the symlink", func() {
				err := fileBundle.Disable()
				Expect(err).NotTo(HaveOccurred())

				fileStats := fs.GetFileTestStat(enablePath)
				Expect(fileStats).NotTo(BeNil())
				Expect(fileStats.FileType).To(Equal(fakesys.FakeFileType(fakesys.FakeFileTypeSymlink)))
				Expect(newerInstallPath).To(Equal(fileStats.SymlinkTarget))
			})
		})

		Context("when the symlink cannot be read", func() {
			It("returns error because we cannot determine if bundle is enabled or disabled", func() {
				fs.ReadLinkError = errors.New("fake-read-link-error")

				err := fileBundle.Disable()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-read-link-error"))
			})
		})
	})

	Describe("Uninstall", func() {
		It("removes the files from disk", func() {
			_, _, err := fileBundle.Install(sourcePath)
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
