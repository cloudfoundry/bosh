package system_test

import (
	boshlog "bosh/logger"
	. "bosh/system"
	"bytes"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
	"io"
	"os"
	"path/filepath"
)

func createOsFs() (fs FileSystem, runner CmdRunner) {
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	runner = NewExecCmdRunner(logger)
	fs = NewOsFileSystem(logger, runner)
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
			assert.NoError(GinkgoT(), err)
			assert.Contains(GinkgoT(), homeDir, "/root")
		})
		It("mkdir all", func() {

			osFs, _ := createOsFs()
			tmpPath := os.TempDir()
			testPath := filepath.Join(tmpPath, "MkdirAllTestDir", "bar", "baz")
			defer os.RemoveAll(filepath.Join(tmpPath, "MkdirAllTestDir"))

			_, err := os.Stat(testPath)
			assert.Error(GinkgoT(), err)
			assert.True(GinkgoT(), os.IsNotExist(err))

			fileMode := os.FileMode(0700)

			err = osFs.MkdirAll(testPath, fileMode)
			assert.NoError(GinkgoT(), err)

			stat, err := os.Stat(testPath)
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), stat.IsDir())
			assert.Equal(GinkgoT(), stat.Mode().Perm(), fileMode)

			err = osFs.MkdirAll(testPath, fileMode)
			assert.NoError(GinkgoT(), err)
		})
		It("chown", func() {

			osFs, _ := createOsFs()
			testPath := filepath.Join(os.TempDir(), "ChownTestDir")

			err := os.Mkdir(testPath, os.FileMode(0700))
			assert.NoError(GinkgoT(), err)
			defer os.RemoveAll(testPath)

			err = osFs.Chown(testPath, "root")
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "not permitted")
		})
		It("chmod", func() {

			osFs, _ := createOsFs()
			testPath := filepath.Join(os.TempDir(), "ChmodTestDir")

			_, err := os.Create(testPath)
			assert.NoError(GinkgoT(), err)
			defer os.Remove(testPath)

			os.Chmod(testPath, os.FileMode(0666))

			err = osFs.Chmod(testPath, os.FileMode(0644))
			assert.NoError(GinkgoT(), err)

			fileStat, err := os.Stat(testPath)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), fileStat.Mode(), os.FileMode(0644))
		})
		It("write to file", func() {

			osFs, _ := createOsFs()
			testPath := filepath.Join(os.TempDir(), "subDir", "WriteToFileTestFile")

			_, err := os.Stat(testPath)
			assert.Error(GinkgoT(), err)

			written, err := osFs.WriteToFile(testPath, "initial write")
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), written)
			defer os.Remove(testPath)

			file, err := os.Open(testPath)
			assert.NoError(GinkgoT(), err)
			defer file.Close()

			assert.Equal(GinkgoT(), readFile(file), "initial write")

			written, err = osFs.WriteToFile(testPath, "second write")
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), written)

			file.Close()
			file, err = os.Open(testPath)
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), readFile(file), "second write")

			file.Close()
			file, err = os.Open(testPath)

			written, err = osFs.WriteToFile(testPath, "second write")
			assert.NoError(GinkgoT(), err)
			assert.False(GinkgoT(), written)
			assert.Equal(GinkgoT(), readFile(file), "second write")
		})
		It("read file", func() {

			osFs, _ := createOsFs()
			testPath := filepath.Join(os.TempDir(), "ReadFileTestFile")

			osFs.WriteToFile(testPath, "some contents")
			defer os.Remove(testPath)

			content, err := osFs.ReadFile(testPath)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "some contents", content)
		})
		It("file exists", func() {

			osFs, _ := createOsFs()
			testPath := filepath.Join(os.TempDir(), "FileExistsTestFile")

			assert.False(GinkgoT(), osFs.FileExists(testPath))

			osFs.WriteToFile(testPath, "initial write")
			defer os.Remove(testPath)

			assert.True(GinkgoT(), osFs.FileExists(testPath))
		})
		It("rename", func() {

			osFs, _ := createOsFs()
			tempDir := os.TempDir()
			oldPath := filepath.Join(tempDir, "old")
			oldFilePath := filepath.Join(oldPath, "test.txt")
			newPath := filepath.Join(tempDir, "new")

			os.Mkdir(oldPath, os.ModePerm)
			_, err := os.Create(oldFilePath)
			assert.NoError(GinkgoT(), err)

			err = osFs.Rename(oldPath, newPath)
			assert.NoError(GinkgoT(), err)

			assert.True(GinkgoT(), osFs.FileExists(newPath))

			newFilePath := filepath.Join(newPath, "test.txt")
			assert.True(GinkgoT(), osFs.FileExists(newFilePath))
		})
		It("symlink", func() {

			osFs, _ := createOsFs()
			filePath := filepath.Join(os.TempDir(), "SymlinkTestFile")
			containingDir := filepath.Join(os.TempDir(), "SubDir")
			os.Remove(containingDir)
			symlinkPath := filepath.Join(containingDir, "SymlinkTestSymlink")

			osFs.WriteToFile(filePath, "some content")
			defer os.Remove(filePath)

			osFs.Symlink(filePath, symlinkPath)
			defer os.Remove(containingDir)

			symlinkStats, err := os.Lstat(symlinkPath)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), os.ModeSymlink, os.ModeSymlink&symlinkStats.Mode())

			symlinkFile, err := os.Open(symlinkPath)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "some content", readFile(symlinkFile))
		})
		It("symlink when link already exists and links to the intended path", func() {

			osFs, _ := createOsFs()
			filePath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1File")
			symlinkPath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1Symlink")

			osFs.WriteToFile(filePath, "some content")
			defer os.Remove(filePath)

			osFs.Symlink(filePath, symlinkPath)
			defer os.Remove(symlinkPath)

			firstSymlinkStats, err := os.Lstat(symlinkPath)
			assert.NoError(GinkgoT(), err)

			err = osFs.Symlink(filePath, symlinkPath)
			assert.NoError(GinkgoT(), err)

			secondSymlinkStats, err := os.Lstat(symlinkPath)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), firstSymlinkStats.ModTime(), secondSymlinkStats.ModTime())
		})
		It("symlink when link already exists and does not link to the intended path", func() {

			osFs, _ := createOsFs()
			filePath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1File")
			otherFilePath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1OtherFile")
			symlinkPath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1Symlink")

			osFs.WriteToFile(filePath, "some content")
			defer os.Remove(filePath)

			osFs.WriteToFile(otherFilePath, "other content")
			defer os.Remove(otherFilePath)

			err := osFs.Symlink(otherFilePath, symlinkPath)
			assert.NoError(GinkgoT(), err)

			err = osFs.Symlink(filePath, symlinkPath)
			assert.NoError(GinkgoT(), err)

			defer os.Remove(symlinkPath)

			symlinkStats, err := os.Lstat(symlinkPath)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), os.ModeSymlink, os.ModeSymlink&symlinkStats.Mode())

			symlinkFile, err := os.Open(symlinkPath)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "some content", readFile(symlinkFile))
		})
		It("symlink when a file exists at intended path", func() {

			osFs, _ := createOsFs()
			filePath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1File")
			symlinkPath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1Symlink")

			osFs.WriteToFile(filePath, "some content")
			defer os.Remove(filePath)

			osFs.WriteToFile(symlinkPath, "some other content")
			defer os.Remove(symlinkPath)

			err := osFs.Symlink(filePath, symlinkPath)
			assert.NoError(GinkgoT(), err)

			defer os.Remove(symlinkPath)

			symlinkStats, err := os.Lstat(symlinkPath)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), os.ModeSymlink, os.ModeSymlink&symlinkStats.Mode())

			symlinkFile, err := os.Open(symlinkPath)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "some content", readFile(symlinkFile))
		})
		It("read link", func() {

			osFs, _ := createOsFs()
			filePath := filepath.Join(os.TempDir(), "SymlinkTestFile")
			containingDir := filepath.Join(os.TempDir(), "SubDir")
			os.Remove(containingDir)
			symlinkPath := filepath.Join(containingDir, "SymlinkTestSymlink")

			osFs.WriteToFile(filePath, "some content")
			defer os.Remove(filePath)

			err := osFs.Symlink(filePath, symlinkPath)
			assert.NoError(GinkgoT(), err)
			defer os.Remove(containingDir)

			actualFilePath, err := osFs.ReadLink(symlinkPath)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), actualFilePath, filePath)
		})
		It("temp file", func() {

			osFs, _ := createOsFs()

			file1, err := osFs.TempFile("fake-prefix")
			assert.NoError(GinkgoT(), err)
			assert.NotEmpty(GinkgoT(), file1)

			defer os.Remove(file1.Name())

			file2, err := osFs.TempFile("fake-prefix")
			assert.NoError(GinkgoT(), err)
			assert.NotEmpty(GinkgoT(), file2)

			defer os.Remove(file2.Name())

			assert.NotEqual(GinkgoT(), file1.Name(), file2.Name())
		})
		It("temp dir", func() {

			osFs, _ := createOsFs()

			path1, err := osFs.TempDir("fake-prefix")
			assert.NoError(GinkgoT(), err)
			assert.NotEmpty(GinkgoT(), path1)

			defer os.Remove(path1)

			path2, err := osFs.TempDir("fake-prefix")
			assert.NoError(GinkgoT(), err)
			assert.NotEmpty(GinkgoT(), path2)

			defer os.Remove(path2)

			assert.NotEqual(GinkgoT(), path1, path2)
		})
		It("copy dir entries", func() {

			osFs, _ := createOsFs()
			srcPath := "../../../fixtures/test_copy_dir_entries"
			destPath, _ := osFs.TempDir("CopyDirEntriesTestDir")
			defer os.RemoveAll(destPath)

			err := osFs.CopyDirEntries(srcPath, destPath)
			assert.NoError(GinkgoT(), err)

			fooContent, err := osFs.ReadFile(destPath + "/foo.txt")
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "foo\n", fooContent)

			barContent, err := osFs.ReadFile(destPath + "/bar/bar.txt")
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "bar\n", barContent)

			assert.True(GinkgoT(), osFs.FileExists(destPath+"/bar/baz"))
		})
		It("copy file", func() {

			osFs, _ := createOsFs()
			srcPath := "../../../fixtures/test_copy_dir_entries/foo.txt"
			dstFile, err := osFs.TempFile("CopyFileTestFile")
			assert.NoError(GinkgoT(), err)
			defer os.Remove(dstFile.Name())

			err = osFs.CopyFile(srcPath, dstFile.Name())

			fooContent, err := osFs.ReadFile(dstFile.Name())
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), fooContent, "foo\n")
		})
		It("remove all", func() {

			osFs, _ := createOsFs()
			dstFile, err := osFs.TempFile("CopyFileTestFile")
			assert.NoError(GinkgoT(), err)
			defer os.Remove(dstFile.Name())

			err = osFs.RemoveAll(dstFile.Name())
			assert.NoError(GinkgoT(), err)

			_, err = os.Stat(dstFile.Name())
			assert.True(GinkgoT(), os.IsNotExist(err))
		})
	})
}
