package system_test

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	osuser "os/user"
	"path/filepath"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"github.com/stretchr/testify/assert"

	"io/ioutil"

	. "github.com/cloudfoundry/bosh-utils/assert"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
	. "github.com/cloudfoundry/bosh-utils/system"
)

func createOsFs() (fs FileSystem) {
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

var _ = Describe("OS FileSystem", func() {
	It("home dir", func() {
		superuser := "root"
		expDir := "/root"
		if Windows {
			u, err := osuser.Current()
			Expect(err).ToNot(HaveOccurred())
			superuser = u.Name
			expDir = `\` + u.Name
		}

		homeDir, err := createOsFs().HomeDir(superuser)
		Expect(err).ToNot(HaveOccurred())

		// path and user names are case-insensitive
		if Windows {
			Expect(strings.ToLower(homeDir)).To(ContainSubstring(strings.ToLower(expDir)))
		} else {
			Expect(homeDir).To(ContainSubstring(expDir))
		}
	})

	It("expand path", func() {
		osFs := createOsFs()

		expandedPath, err := osFs.ExpandPath("~/fake-dir/fake-file.txt")
		Expect(err).ToNot(HaveOccurred())

		currentUser, err := osuser.Current()
		Expect(err).ToNot(HaveOccurred())
		Expect(expandedPath).To(MatchPath(currentUser.HomeDir + "/fake-dir/fake-file.txt"))

		expandedPath, err = osFs.ExpandPath("/fake-dir//fake-file.txt")
		Expect(err).ToNot(HaveOccurred())
		Expect(expandedPath).To(MatchPath("/fake-dir/fake-file.txt"))

		expandedPath, err = osFs.ExpandPath("./fake-file.txt")
		Expect(err).ToNot(HaveOccurred())
		currentDir, err := os.Getwd()
		Expect(err).ToNot(HaveOccurred())
		Expect(expandedPath).To(MatchPath(currentDir + "/fake-file.txt"))
	})

	It("mkdir all", func() {
		osFs := createOsFs()
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

		err = osFs.MkdirAll(testPath, fileMode)
		Expect(err).ToNot(HaveOccurred())
	})

	It("chown", func() {
		osFs := createOsFs()
		testPath := filepath.Join(os.TempDir(), "ChownTestDir")

		err := os.Mkdir(testPath, os.FileMode(0700))
		Expect(err).ToNot(HaveOccurred())
		defer os.RemoveAll(testPath)

		err = osFs.Chown(testPath, "garbage-foo")
		Expect(err).To(HaveOccurred())
	})

	It("chmod", func() {
		osFs := createOsFs()
		testPath := filepath.Join(os.TempDir(), "ChmodTestDir")
		compPath := filepath.Join(os.TempDir(), "Comparison")

		_, err := os.Create(testPath)
		Expect(err).ToNot(HaveOccurred())
		defer os.Remove(testPath)

		_, err = os.Create(compPath)
		Expect(err).ToNot(HaveOccurred())
		defer os.Remove(compPath)

		err = os.Chmod(testPath, os.FileMode(0666))
		Expect(err).ToNot(HaveOccurred())

		err = os.Chmod(compPath, os.FileMode(0666))
		Expect(err).ToNot(HaveOccurred())

		fileStat, err := os.Stat(testPath)
		compStat, err := os.Stat(compPath)
		Expect(err).ToNot(HaveOccurred())
		Expect(fileStat.Mode()).To(Equal(compStat.Mode()))

		err = osFs.Chmod(testPath, os.FileMode(0644))
		Expect(err).ToNot(HaveOccurred())

		err = os.Chmod(compPath, os.FileMode(0644))
		Expect(err).ToNot(HaveOccurred())

		fileStat, err = os.Stat(testPath)
		compStat, err = os.Stat(compPath)
		Expect(err).ToNot(HaveOccurred())
		Expect(fileStat.Mode()).To(Equal(compStat.Mode()))
	})

	It("opens file", func() {
		osFs := createOsFs()
		testPath := filepath.Join(os.TempDir(), "OpenFileTestFile")

		file, err := osFs.OpenFile(testPath, os.O_RDWR|os.O_CREATE|os.O_TRUNC, os.FileMode(0644))
		defer os.Remove(testPath)

		Expect(err).ToNot(HaveOccurred())

		file.Write([]byte("testing new file"))
		file.Close()

		createdFile, err := os.Open(testPath)
		Expect(err).ToNot(HaveOccurred())
		defer createdFile.Close()
		Expect(readFile(createdFile)).To(Equal("testing new file"))
	})

	Describe("Stat", func() {
		It("returns file info", func() {
			osFs := createOsFs()
			testPath := filepath.Join(os.TempDir(), "OpenFileTestFile")

			file, err := osFs.OpenFile(testPath, os.O_RDWR|os.O_CREATE|os.O_TRUNC, 0644)
			Expect(err).ToNot(HaveOccurred())
			defer file.Close()
			defer os.Remove(testPath)

			fsInfo, err := osFs.Stat(testPath)
			Expect(err).ToNot(HaveOccurred())

			// Go standard library
			osInfo, err := os.Stat(testPath)
			Expect(err).ToNot(HaveOccurred())

			Expect(os.SameFile(fsInfo, osInfo)).To(BeTrue())
		})
	})

	Context("the file already exists and is not write only", func() {
		It("writes to file", func() {
			osFs := createOsFs()
			testPath := filepath.Join(os.TempDir(), "subDir", "ConvergeFileContentsTestFile")

			if _, err := os.Stat(testPath); err == nil {
				Expect(os.Remove(testPath)).To(Succeed())
			}

			written, err := osFs.ConvergeFileContents(testPath, []byte("initial write"))
			defer os.Remove(testPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(written).To(BeTrue())

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
			osFs := createOsFs()
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
			osFs := createOsFs()

			testPath := filepath.Join(os.TempDir(), "subDirNew", "ConvergeFileContentsTestFile")

			err := osFs.WriteFile(testPath, []byte("test"))
			Expect(err).ToNot(HaveOccurred())
		})
	})

	It("read file", func() {
		osFs := createOsFs()
		testPath := filepath.Join(os.TempDir(), "ReadFileTestFile")

		osFs.WriteFileString(testPath, "some contents")
		defer os.Remove(testPath)

		content, err := osFs.ReadFile(testPath)
		Expect(err).ToNot(HaveOccurred())
		Expect("some contents").To(Equal(string(content)))
	})

	It("file exists", func() {
		osFs := createOsFs()
		testPath := filepath.Join(os.TempDir(), "FileExistsTestFile")

		Expect(osFs.FileExists(testPath)).To(BeFalse())

		osFs.WriteFileString(testPath, "initial write")
		defer os.Remove(testPath)

		Expect(osFs.FileExists(testPath)).To(BeTrue())
	})

	It("rename", func() {
		osFs := createOsFs()
		tempDir := os.TempDir()
		oldPath := filepath.Join(tempDir, "old")
		oldFilePath := filepath.Join(oldPath, "test.txt")
		newPath := filepath.Join(tempDir, "new")

		os.Mkdir(oldPath, os.ModePerm)
		f, err := os.Create(oldFilePath)
		Expect(err).ToNot(HaveOccurred())
		f.Close()

		err = osFs.Rename(oldPath, newPath)
		Expect(err).ToNot(HaveOccurred())

		Expect(osFs.FileExists(newPath)).To(BeTrue())

		newFilePath := filepath.Join(newPath, "test.txt")
		Expect(osFs.FileExists(newFilePath)).To(BeTrue())
	})

	Describe("Symlink", func() {
		var TempDir string
		BeforeEach(func() {
			var err error
			TempDir, err = ioutil.TempDir("", "")
			Expect(err).ToNot(HaveOccurred())
		})
		AfterEach(func() {
			os.RemoveAll(TempDir)
		})

		It("creates a symlink", func() {
			osFs := createOsFs()
			filePath := filepath.Join(TempDir, "SymlinkTestFile")
			containingDir := filepath.Join(TempDir, "SubDir")
			os.Remove(containingDir)
			symlinkPath := filepath.Join(containingDir, "SymlinkTestSymlink")

			osFs.WriteFileString(filePath, "some content")
			osFs.Symlink(filePath, symlinkPath)

			symlinkStats, err := os.Lstat(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(os.ModeSymlink).To(Equal(os.ModeSymlink & symlinkStats.Mode()))

			symlinkFile, err := os.Open(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect("some content").To(Equal(readFile(symlinkFile)))
		})

		It("does not modify the link when it already exists and links to the intended path", func() {
			filePath := filepath.Join(TempDir, "SymlinkTestIdempotent1File")
			symlinkPath := filepath.Join(TempDir, "SymlinkTestIdempotent1Symlink")

			osFs := createOsFs()
			osFs.WriteFileString(filePath, "some content")

			osFs.Symlink(filePath, symlinkPath)

			firstSymlinkStats, err := os.Lstat(symlinkPath)
			Expect(err).ToNot(HaveOccurred())

			err = osFs.Symlink(filePath, symlinkPath)
			Expect(err).ToNot(HaveOccurred())

			secondSymlinkStats, err := os.Lstat(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(firstSymlinkStats.ModTime()).To(Equal(secondSymlinkStats.ModTime()))
		})

		It("removes the old link when it already exists and does not link to the intended path", func() {
			osFs := createOsFs()
			filePath := filepath.Join(TempDir, "SymlinkTestIdempotent1File")
			otherFilePath := filepath.Join(TempDir, "SymlinkTestIdempotent1OtherFile")
			symlinkPath := filepath.Join(TempDir, "SymlinkTestIdempotent1Symlink")

			osFs.WriteFileString(filePath, "some content")
			osFs.WriteFileString(otherFilePath, "other content")

			err := osFs.Symlink(otherFilePath, symlinkPath)
			Expect(err).ToNot(HaveOccurred())

			err = osFs.Symlink(filePath, symlinkPath)
			Expect(err).ToNot(HaveOccurred())

			symlinkStats, err := os.Lstat(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(os.ModeSymlink).To(Equal(os.ModeSymlink & symlinkStats.Mode()))

			symlinkFile, err := os.Open(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect("some content").To(Equal(readFile(symlinkFile)))
		})

		It("deletes a file if it exists at the intended path", func() {
			osFs := createOsFs()
			filePath := filepath.Join(TempDir, "SymlinkTestIdempotent1File")
			symlinkPath := filepath.Join(TempDir, "SymlinkTestIdempotent1Symlink")

			osFs.WriteFileString(filePath, "some content")
			osFs.WriteFileString(symlinkPath, "some other content")

			err := osFs.Symlink(filePath, symlinkPath)
			Expect(err).ToNot(HaveOccurred())

			symlinkStats, err := os.Lstat(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(os.ModeSymlink).To(Equal(os.ModeSymlink & symlinkStats.Mode()))

			symlinkFile, err := os.Open(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect("some content").To(Equal(readFile(symlinkFile)))
		})

		It("deletes a broken symlink if it exists at the intended path", func() {
			osFs := createOsFs()
			fileA := filepath.Join(TempDir, "file_a")
			fileB := filepath.Join(TempDir, "file_b")
			symlinkPath := filepath.Join(TempDir, "symlink")

			osFs.WriteFileString(fileA, "file a")
			osFs.WriteFileString(fileB, "file b")

			err := osFs.Symlink(fileA, symlinkPath)
			Expect(err).ToNot(HaveOccurred())

			os.Remove(fileA) // creates a broken symlink

			err = osFs.Symlink(fileB, symlinkPath)
			Expect(err).ToNot(HaveOccurred())

			symlinkStats, err := os.Lstat(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect(os.ModeSymlink).To(Equal(os.ModeSymlink & symlinkStats.Mode()))

			symlinkFile, err := os.Open(symlinkPath)
			Expect(err).ToNot(HaveOccurred())
			Expect("file b").To(Equal(readFile(symlinkFile)))

		})

		testSymlinkDir := func(sourceDir, targetDir string) {
			const Content = "Hello!"
			osFs := createOsFs()

			Expect(osFs.MkdirAll(sourceDir, 0700)).To(Succeed())

			Expect(osFs.Symlink(sourceDir, targetDir)).To(Succeed())

			sourceFile := filepath.Join(sourceDir, "file.txt")
			targetFile := filepath.Join(targetDir, "file.txt")

			Expect(osFs.WriteFileString(targetFile, Content)).To(Succeed())
			s, err := osFs.ReadFileString(targetFile)
			Expect(err).To(Succeed())
			Expect(s).To(Equal(Content))

			s, err = osFs.ReadFileString(sourceFile)
			Expect(err).To(Succeed())
			Expect(s).To(Equal(Content))

			names, err := ioutil.ReadDir(targetDir)
			Expect(err).To(Succeed())
			Expect(names).To(HaveLen(1))
			Expect(names[0].Name()).To(Equal("file.txt"))
		}

		It("creates links to a directory", func() {
			sourceDir := filepath.Join(TempDir, "dir_a")
			targetDir := filepath.Join(TempDir, "dir_b")
			testSymlinkDir(sourceDir, targetDir)
		})

		It("creates links to a directory when the source and target paths are not absolute", func() {
			sourceDir := filepath.Join(TempDir, "dir_a")
			targetDir := filepath.Join(TempDir, "dir_b")

			// On Windows this removes the volume name - on Unix this is a no-op
			sourceDir = strings.TrimPrefix(sourceDir, filepath.VolumeName(sourceDir))
			targetDir = strings.TrimPrefix(targetDir, filepath.VolumeName(targetDir))

			testSymlinkDir(sourceDir, targetDir)
		})
	})

	It("read and follow link", func() {
		osFs := createOsFs()
		targetPath := filepath.Join(os.TempDir(), "SymlinkTestFile")
		containingDir := filepath.Join(os.TempDir(), "SubDir")
		symlinkPath := filepath.Join(containingDir, "SymlinkTestSymlink")

		osFs.WriteFileString(targetPath, "some content")
		defer os.Remove(targetPath)

		err := osFs.Symlink(targetPath, symlinkPath)
		Expect(err).ToNot(HaveOccurred())
		defer os.Remove(symlinkPath)
		defer os.Remove(containingDir)

		actualFilePath, err := osFs.ReadAndFollowLink(symlinkPath)
		Expect(err).ToNot(HaveOccurred())

		// on Mac OS /var -> private/var
		absPath, err := filepath.EvalSymlinks(targetPath)
		Expect(err).ToNot(HaveOccurred())
		Expect(actualFilePath).To(MatchPath(absPath))
	})

	Context("read link", func() {
		var (
			osFs          FileSystem
			symlinkPath   string
			containingDir string
			targetPath    string
		)

		BeforeEach(func() {
			osFs = createOsFs()
			symlinkPath = filepath.Join(os.TempDir(), "SymlinkTestFile")
			containingDir = filepath.Join(os.TempDir(), "SubDir")
			targetPath = filepath.Join(containingDir, "TestSymlinkTarget")
		})

		AfterEach(func() {
			os.Remove(symlinkPath)
			os.Remove(targetPath)
			os.Remove(containingDir)
		})

		Context("when the link does not exist", func() {
			It("returns an error", func() {
				Expect(osFs.FileExists(symlinkPath)).To(Equal(false))

				_, err := osFs.Readlink(symlinkPath)
				Expect(err).To(HaveOccurred())
			})
		})

		Context("when the target path does not exist", func() {
			It("returns the target path without error", func() {
				err := osFs.Symlink(targetPath, symlinkPath)
				Expect(err).ToNot(HaveOccurred())

				targetFilePath, err := osFs.Readlink(symlinkPath)

				Expect(osFs.FileExists(targetPath)).To(Equal(false))

				Expect(err).ToNot(HaveOccurred())
				Expect(targetFilePath).To(MatchPath(targetPath))
			})
		})

		Context("when the target path exists", func() {
			It("returns the target path without error", func() {
				err := osFs.MkdirAll(containingDir, os.FileMode(0700))
				Expect(err).ToNot(HaveOccurred())

				err = osFs.WriteFileString(targetPath, "test-data")
				Expect(err).ToNot(HaveOccurred())

				err = osFs.Symlink(targetPath, symlinkPath)
				Expect(err).ToNot(HaveOccurred())

				Expect(osFs.FileExists(targetPath)).To(Equal(true))

				targetFilePath, err := osFs.Readlink(symlinkPath)

				Expect(err).ToNot(HaveOccurred())
				Expect(targetFilePath).To(Equal(targetPath))
			})
		})
	})

	It("temp file", func() {
		osFs := createOsFs()

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
		osFs := createOsFs()

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

	Describe("Temporary directories and files", func() {
		var (
			osFs        FileSystem
			testTempDir string
		)
		BeforeEach(func() {
			osFs = createOsFs()
			var err error
			testTempDir, err = ioutil.TempDir("", "os_filesystem_test")
			Expect(err).ToNot(HaveOccurred())
		})

		AfterEach(func() {
			os.Remove(testTempDir)
		})

		Context("a temp root is set", func() {
			BeforeEach(func() {
				osFs.ChangeTempRoot(testTempDir)
			})

			It("creates temp files under that root", func() {
				file, err := osFs.TempFile("some-file-prefix")
				Expect(err).ToNot(HaveOccurred())
				Expect(file.Name()).To(HavePrefix(filepath.Join(testTempDir, "some-file-prefix")))
			})

			It("creates temp directories under that root", func() {
				dirName, err := osFs.TempDir("some-dir-prefix")
				Expect(err).ToNot(HaveOccurred())
				Expect(dirName).To(HavePrefix(filepath.Join(testTempDir, "some-dir-prefix")))
			})
		})

		Context("no temp root is set and was initialized as a strict temp root", func() {
			BeforeEach(func() {
				osFs = NewOsFileSystemWithStrictTempRoot(boshlog.NewLogger(boshlog.LevelNone))
			})

			It("should eror", func() {
				_, err := osFs.TempFile("some-prefix")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("ChangeTempRoot"))

				_, err = osFs.TempDir("some-prefix")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("ChangeTempRoot"))
			})
		})
	})

	Describe("CopyFile", func() {
		It("copies file", func() {
			osFs := createOsFs()
			srcPath := "test_assets/test_copy_dir_entries/foo.txt"
			srcContent, err := osFs.ReadFileString(srcPath)
			Expect(err).ToNot(HaveOccurred())
			dstFile, err := osFs.TempFile("CopyFileTestFile")
			Expect(err).ToNot(HaveOccurred())
			defer os.Remove(dstFile.Name())

			err = osFs.CopyFile(srcPath, dstFile.Name())

			fooContent, err := osFs.ReadFileString(dstFile.Name())
			Expect(err).ToNot(HaveOccurred())
			Expect(fooContent).To(Equal(srcContent))
		})

		It("does not leak file descriptors", func() {
			cmdName := "lsof"
			if Windows {
				if _, err := exec.LookPath("handle.exe"); err != nil {
					Skip("This test requires handle.exe it can be downloaded here:\n" +
						"https://technet.microsoft.com/en-us/sysinternals/handle.aspx")
				}
				cmdName = "handle.exe"
			}
			osFs := createOsFs()

			srcFile, err := osFs.TempFile("srcPath")
			Expect(err).ToNot(HaveOccurred())
			defer os.Remove(srcFile.Name())

			err = srcFile.Close()
			Expect(err).ToNot(HaveOccurred())

			dstFile, err := osFs.TempFile("dstPath")
			Expect(err).ToNot(HaveOccurred())
			defer os.Remove(dstFile.Name())

			err = dstFile.Close()
			Expect(err).ToNot(HaveOccurred())

			err = osFs.CopyFile(srcFile.Name(), dstFile.Name())
			Expect(err).ToNot(HaveOccurred())

			runner := NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelNone))
			stdout, _, _, err := runner.RunCommand(cmdName)
			Expect(err).ToNot(HaveOccurred())

			for _, line := range strings.Split(stdout, "\n") {
				if strings.Contains(line, srcFile.Name()) {
					Fail(fmt.Sprintf("CopyFile did not close: srcFile: %s", srcFile.Name()))
				}
				if strings.Contains(line, dstFile.Name()) {
					Fail(fmt.Sprintf("CopyFile did not close: dstFile: %s", dstFile.Name()))
				}
			}
		})
	})

	Describe("CopyDir", func() {
		var fixtureFiles = []string{
			"foo.txt",
			"bar/bar.txt",
			"bar/baz/.gitkeep",
		}

		It("recursively copies directory contents", func() {
			osFs := createOsFs()
			srcPath := "test_assets/test_copy_dir_entries"
			dstPath, err := osFs.TempDir("CopyDirTestDir")
			Expect(err).ToNot(HaveOccurred())
			defer osFs.RemoveAll(dstPath)

			err = osFs.CopyDir(srcPath, dstPath)
			Expect(err).ToNot(HaveOccurred())

			for _, fixtureFile := range fixtureFiles {
				srcContents, err := osFs.ReadFile(filepath.Join(srcPath, fixtureFile))
				Expect(err).ToNot(HaveOccurred())

				dstContents, err := osFs.ReadFile(filepath.Join(dstPath, fixtureFile))
				Expect(err).ToNot(HaveOccurred())

				Expect(srcContents).To(Equal(dstContents), "Copied file does not match source file: '%s", fixtureFile)
			}
		})

		It("does not leak file descriptors", func() {
			cmdName := "lsof"
			if Windows {
				if _, err := exec.LookPath("handle.exe"); err != nil {
					Skip("This test requires handle.exe it can be downloaded here:\n" +
						"https://technet.microsoft.com/en-us/sysinternals/handle.aspx")
				}
				cmdName = "handle.exe"
			}

			osFs := createOsFs()
			srcPath := "test_assets/test_copy_dir_entries"
			dstPath, err := osFs.TempDir("CopyDirTestDir")
			Expect(err).ToNot(HaveOccurred())
			defer osFs.RemoveAll(dstPath)

			err = osFs.CopyDir(srcPath, dstPath)
			Expect(err).ToNot(HaveOccurred())

			runner := NewExecCmdRunner(boshlog.NewLogger(boshlog.LevelNone))
			stdout, _, _, err := runner.RunCommand(cmdName)
			Expect(err).ToNot(HaveOccurred())

			// lsof and handle use absolute paths
			srcPath, err = filepath.Abs(srcPath)
			Expect(err).ToNot(HaveOccurred())

			for _, line := range strings.Split(stdout, "\n") {
				for _, fixtureFile := range fixtureFiles {
					srcFilePath := filepath.Join(srcPath, fixtureFile)
					if strings.Contains(line, srcFilePath) {
						Fail(fmt.Sprintf("CopyDir did not close source file: %s", srcFilePath))
					}

					srcFileDirPath := filepath.Dir(srcFilePath)
					if strings.Contains(line, srcFileDirPath) {
						Fail(fmt.Sprintf("CopyDir did not close source dir: %s", srcFileDirPath))
					}

					dstFilePath := filepath.Join(dstPath, fixtureFile)
					if strings.Contains(line, dstFilePath) {
						Fail(fmt.Sprintf("CopyDir did not close destination file: %s", dstFilePath))
					}

					dstFileDirPath := filepath.Dir(dstFilePath)
					if strings.Contains(line, dstFileDirPath) {
						Fail(fmt.Sprintf("CopyDir did not close destination dir: %s", dstFileDirPath))
					}
				}
			}
		})
	})

	It("remove all", func() {
		osFs := createOsFs()

		dstFile, err := osFs.TempFile("CopyFileTestFile")
		Expect(err).ToNot(HaveOccurred())

		dstPath := dstFile.Name()
		defer os.Remove(dstPath)
		dstFile.Close()

		err = osFs.RemoveAll(dstFile.Name())
		Expect(err).ToNot(HaveOccurred())

		_, err = os.Stat(dstFile.Name())
		Expect(os.IsNotExist(err)).To(BeTrue())
	})
})
