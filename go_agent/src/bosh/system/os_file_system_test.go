package system_test

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	boshlog "bosh/logger"
	. "bosh/system"
)

func createOsFs() (fs FileSystem, runner CmdRunner) {
	logger := boshlog.NewLogger(boshlog.LevelNone)
	fs = NewOsFileSystem(logger)
	return
}

func readFile(file *os.File) string {
	buf := &bytes.Buffer{}
	_, err := io.Copy(buf, file)

	if err != nil {
		return ""
	}

	return string(buf.Bytes())
}

func init() {
	Describe("Testing with Ginkgo", func() {
		It("home dir", func() {
			osFs, _ := createOsFs()

			homeDir, err := osFs.HomeDir("root")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), homeDir, "/root")
		})

		It("mkdir all", func() {
			osFs, _ := createOsFs()
			tmpPath := os.TempDir()
			testPath := filepath.Join(tmpPath, "MkdirAllTestDir", "bar", "baz")
			defer os.RemoveAll(filepath.Join(tmpPath, "MkdirAllTestDir"))

			_, err := os.Stat(testPath)
			Expect(err).To(HaveOccurred())
			Expect(os.IsNotExist(err)).To(BeTrue())

			fileMode := os.FileMode(0700)

			err = osFs.MkdirAll(testPath, fileMode)
			Expect(err).ToNot(HaveOccurred())

			stat, err := os.Stat(testPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(stat.IsDir()).To(BeTrue())
			Expect(stat.Mode().Perm()).To(Equal(fileMode))

			err = osFs.MkdirAll(testPath, fileMode)
			Expect(err).ToNot(HaveOccurred())
		})

		It("chown", func() {
			osFs, _ := createOsFs()
			testPath := filepath.Join(os.TempDir(), "ChownTestDir")

			err := os.Mkdir(testPath, os.FileMode(0700))
			Expect(err).ToNot(HaveOccurred())
			defer os.RemoveAll(testPath)

			err = osFs.Chown(testPath, "root")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("not permitted"))
		})

		It("chmod", func() {
			osFs, _ := createOsFs()
			testPath := filepath.Join(os.TempDir(), "ChmodTestDir")

			_, err := os.Create(testPath)
			Expect(err).ToNot(HaveOccurred())
			defer os.Remove(testPath)

			os.Chmod(testPath, os.FileMode(0666))

			err = osFs.Chmod(testPath, os.FileMode(0644))
			Expect(err).ToNot(HaveOccurred())

			fileStat, err := os.Stat(testPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(fileStat.Mode()).To(Equal(os.FileMode(0644)))
		})

		Context("the file already exists and is not write only", func() {
			It("writes to file", func() {
				osFs, _ := createOsFs()
				testPath := filepath.Join(os.TempDir(), "subDir", "ConvergeFileContentsTestFile")

				_, err := os.Stat(testPath)
				Expect(err).To(HaveOccurred())

				written, err := osFs.ConvergeFileContents(testPath, []byte("initial write"))
				Expect(err).ToNot(HaveOccurred())
				Expect(written).To(BeTrue())
				defer os.Remove(testPath)

				file, err := os.Open(testPath)
				Expect(err).ToNot(HaveOccurred())
				defer file.Close()

				Expect(readFile(file)).To(Equal("initial write"))

				written, err = osFs.ConvergeFileContents(testPath, []byte("second write"))
				Expect(err).ToNot(HaveOccurred())
				Expect(written).To(BeTrue())

				file.Close()
				file, err = os.Open(testPath)
				Expect(err).ToNot(HaveOccurred())

				Expect(readFile(file)).To(Equal("second write"))

				file.Close()
				file, err = os.Open(testPath)

				written, err = osFs.ConvergeFileContents(testPath, []byte("second write"))
				Expect(err).ToNot(HaveOccurred())
				Expect(written).To(BeFalse())
				Expect(readFile(file)).To(Equal("second write"))
			})
		})

		Context("the file already exists and is write only", func() {
			It("writes to file", func() {
				osFs, _ := createOsFs()
				testPath := filepath.Join(os.TempDir(), "subDir", "ConvergeFileContentsTestFile")

				_, err := os.OpenFile(testPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, os.FileMode(0200))
				Expect(err).ToNot(HaveOccurred())
				defer os.Remove(testPath)

				err = osFs.WriteFile(testPath, []byte("test"))
				Expect(err).ToNot(HaveOccurred())
			})
		})

		Context("the file parent fir does not exist", func() {
			BeforeEach(func() {
				err := os.RemoveAll(filepath.Join(os.TempDir(), "subDirNew"))
				Expect(err).ToNot(HaveOccurred())
			})

			AfterEach(func() {
				err := os.RemoveAll(filepath.Join(os.TempDir(), "subDirNew"))
				Expect(err).ToNot(HaveOccurred())
			})

			It("writes to file", func() {
				osFs, _ := createOsFs()

				testPath := filepath.Join(os.TempDir(), "subDirNew", "ConvergeFileContentsTestFile")

				err := osFs.WriteFile(testPath, []byte("test"))
				Expect(err).ToNot(HaveOccurred())
			})
		})

		It("read file", func() {
			osFs, _ := createOsFs()
			testPath := filepath.Join(os.TempDir(), "ReadFileTestFile")

			osFs.WriteFileString(testPath, "some contents")
			defer os.Remove(testPath)

			content, err := osFs.ReadFile(testPath)
			Expect(err).ToNot(HaveOccurred())
			Expect("some contents").To(Equal(string(content)))
		})

		It("file exists", func() {
			osFs, _ := createOsFs()
			testPath := filepath.Join(os.TempDir(), "FileExistsTestFile")

			Expect(osFs.FileExists(testPath)).To(BeFalse())

			osFs.WriteFileString(testPath, "initial write")
			defer os.Remove(testPath)

			Expect(osFs.FileExists(testPath)).To(BeTrue())
		})

		It("rename", func() {
			osFs, _ := createOsFs()
			tempDir := os.TempDir()
			oldPath := filepath.Join(tempDir, "old")
			oldFilePath := filepath.Join(oldPath, "test.txt")
			newPath := filepath.Join(tempDir, "new")

			os.Mkdir(oldPath, os.ModePerm)
			_, err := os.Create(oldFilePath)
			Expect(err).ToNot(HaveOccurred())

			err = osFs.Rename(oldPath, newPath)
			Expect(err).ToNot(HaveOccurred())

			Expect(osFs.FileExists(newPath)).To(BeTrue())

			newFilePath := filepath.Join(newPath, "test.txt")
			Expect(osFs.FileExists(newFilePath)).To(BeTrue())
		})

		It("symlink", func() {
			osFs, _ := createOsFs()
			filePath := filepath.Join(os.TempDir(), "SymlinkTestFile")
			containingDir := filepath.Join(os.TempDir(), "SubDir")
			os.Remove(containingDir)
			symlinkPath := filepath.Join(containingDir, "SymlinkTestSymlink")

			osFs.WriteFileString(filePath, "some content")
			defer os.Remove(filePath)

			osFs.Symlink(filePath, symlinkPath)
			defer os.Remove(containingDir)

			symlinkStats, err := os.Lstat(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(os.ModeSymlink).To(Equal(os.ModeSymlink & symlinkStats.Mode()))

			symlinkFile, err := os.Open(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect("some content").To(Equal(readFile(symlinkFile)))
		})

		It("symlink when link already exists and links to the intended path", func() {
			osFs, _ := createOsFs()
			filePath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1File")
			symlinkPath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1Symlink")

			osFs.WriteFileString(filePath, "some content")
			defer os.Remove(filePath)

			osFs.Symlink(filePath, symlinkPath)
			defer os.Remove(symlinkPath)

			firstSymlinkStats, err := os.Lstat(symlinkPath)
			Expect(err).ToNot(HaveOccurred())

			err = osFs.Symlink(filePath, symlinkPath)
			Expect(err).ToNot(HaveOccurred())

			secondSymlinkStats, err := os.Lstat(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(firstSymlinkStats.ModTime()).To(Equal(secondSymlinkStats.ModTime()))
		})

		It("symlink when link already exists and does not link to the intended path", func() {
			osFs, _ := createOsFs()
			filePath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1File")
			otherFilePath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1OtherFile")
			symlinkPath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1Symlink")

			osFs.WriteFileString(filePath, "some content")
			defer os.Remove(filePath)

			osFs.WriteFileString(otherFilePath, "other content")
			defer os.Remove(otherFilePath)

			err := osFs.Symlink(otherFilePath, symlinkPath)
			Expect(err).ToNot(HaveOccurred())

			err = osFs.Symlink(filePath, symlinkPath)
			Expect(err).ToNot(HaveOccurred())

			defer os.Remove(symlinkPath)

			symlinkStats, err := os.Lstat(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(os.ModeSymlink).To(Equal(os.ModeSymlink & symlinkStats.Mode()))

			symlinkFile, err := os.Open(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect("some content").To(Equal(readFile(symlinkFile)))
		})

		It("symlink when a file exists at intended path", func() {
			osFs, _ := createOsFs()
			filePath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1File")
			symlinkPath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1Symlink")

			osFs.WriteFileString(filePath, "some content")
			defer os.Remove(filePath)

			osFs.WriteFileString(symlinkPath, "some other content")
			defer os.Remove(symlinkPath)

			err := osFs.Symlink(filePath, symlinkPath)
			Expect(err).ToNot(HaveOccurred())

			defer os.Remove(symlinkPath)

			symlinkStats, err := os.Lstat(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(os.ModeSymlink).To(Equal(os.ModeSymlink & symlinkStats.Mode()))

			symlinkFile, err := os.Open(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect("some content").To(Equal(readFile(symlinkFile)))
		})

		It("read link", func() {
			osFs, _ := createOsFs()
			filePath := filepath.Join(os.TempDir(), "SymlinkTestFile")
			containingDir := filepath.Join(os.TempDir(), "SubDir")
			os.Remove(containingDir)
			symlinkPath := filepath.Join(containingDir, "SymlinkTestSymlink")

			osFs.WriteFileString(filePath, "some content")
			defer os.Remove(filePath)

			err := osFs.Symlink(filePath, symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			defer os.Remove(containingDir)

			actualFilePath, err := osFs.ReadLink(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(actualFilePath).To(Equal(filePath))
		})

		It("temp file", func() {
			osFs, _ := createOsFs()

			file1, err := osFs.TempFile("fake-prefix")
			Expect(err).ToNot(HaveOccurred())
			assert.NotEmpty(GinkgoT(), file1)

			defer os.Remove(file1.Name())

			file2, err := osFs.TempFile("fake-prefix")
			Expect(err).ToNot(HaveOccurred())
			assert.NotEmpty(GinkgoT(), file2)

			defer os.Remove(file2.Name())

			assert.NotEqual(GinkgoT(), file1.Name(), file2.Name())
		})

		It("temp dir", func() {
			osFs, _ := createOsFs()

			path1, err := osFs.TempDir("fake-prefix")
			Expect(err).ToNot(HaveOccurred())
			assert.NotEmpty(GinkgoT(), path1)

			defer os.Remove(path1)

			path2, err := osFs.TempDir("fake-prefix")
			Expect(err).ToNot(HaveOccurred())
			assert.NotEmpty(GinkgoT(), path2)

			defer os.Remove(path2)

			assert.NotEqual(GinkgoT(), path1, path2)
		})

		Describe("CopyFile", func() {
			It("copies file", func() {
				osFs, _ := createOsFs()
				srcPath := "../../../fixtures/test_copy_dir_entries/foo.txt"
				dstFile, err := osFs.TempFile("CopyFileTestFile")
				Expect(err).ToNot(HaveOccurred())
				defer os.Remove(dstFile.Name())

				err = osFs.CopyFile(srcPath, dstFile.Name())

				fooContent, err := osFs.ReadFileString(dstFile.Name())
				Expect(err).ToNot(HaveOccurred())
				Expect(fooContent).To(Equal("foo\n"))
			})

			It("does not leak file descriptors", func() {
				osFs, _ := createOsFs()

				srcFile, err := osFs.TempFile("srcPath")
				Expect(err).ToNot(HaveOccurred())

				err = srcFile.Close()
				Expect(err).ToNot(HaveOccurred())

				dstFile, err := osFs.TempFile("dstPath")
				Expect(err).ToNot(HaveOccurred())

				err = dstFile.Close()
				Expect(err).ToNot(HaveOccurred())

				err = osFs.CopyFile(srcFile.Name(), dstFile.Name())
				Expect(err).ToNot(HaveOccurred())

				runner := NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelNone))
				stdout, _, _, err := runner.RunCommand("lsof")
				Expect(err).ToNot(HaveOccurred())

				for _, line := range strings.Split(stdout, "\n") {
					if strings.Contains(line, srcFile.Name()) {
						Fail(fmt.Sprintf("CopyFile did not close: srcFile: %s", srcFile.Name()))
					}
					if strings.Contains(line, dstFile.Name()) {
						Fail(fmt.Sprintf("CopyFile did not close: dstFile: %s", dstFile.Name()))
					}
				}

				os.Remove(srcFile.Name())
				os.Remove(dstFile.Name())
			})
		})

		It("remove all", func() {
			osFs, _ := createOsFs()
			dstFile, err := osFs.TempFile("CopyFileTestFile")
			Expect(err).ToNot(HaveOccurred())
			defer os.Remove(dstFile.Name())

			err = osFs.RemoveAll(dstFile.Name())
			Expect(err).ToNot(HaveOccurred())

			_, err = os.Stat(dstFile.Name())
			Expect(os.IsNotExist(err)).To(BeTrue())
		})
	})
}
