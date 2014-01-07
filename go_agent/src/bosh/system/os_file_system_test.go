package system

import (
	boshlog "bosh/logger"
	"bytes"
	"github.com/stretchr/testify/assert"
	"io"
	"os"
	"path/filepath"
	"testing"
)

func TestHomeDir(t *testing.T) {
	osFs, _ := createOsFs()

	homeDir, err := osFs.HomeDir("root")
	assert.NoError(t, err)
	assert.Contains(t, homeDir, "/root")
}

func TestMkdirAll(t *testing.T) {
	osFs, _ := createOsFs()
	tmpPath := os.TempDir()
	testPath := filepath.Join(tmpPath, "MkdirAllTestDir", "bar", "baz")
	defer os.RemoveAll(filepath.Join(tmpPath, "MkdirAllTestDir"))

	_, err := os.Stat(testPath)
	assert.Error(t, err)
	assert.True(t, os.IsNotExist(err))

	fileMode := os.FileMode(0700)

	err = osFs.MkdirAll(testPath, fileMode)
	assert.NoError(t, err)

	stat, err := os.Stat(testPath)
	assert.NoError(t, err)
	assert.True(t, stat.IsDir())
	assert.Equal(t, stat.Mode().Perm(), fileMode)

	// check idempotency
	err = osFs.MkdirAll(testPath, fileMode)
	assert.NoError(t, err)
}

func TestChown(t *testing.T) {
	osFs, _ := createOsFs()
	testPath := filepath.Join(os.TempDir(), "ChownTestDir")

	err := os.Mkdir(testPath, os.FileMode(0700))
	assert.NoError(t, err)
	defer os.RemoveAll(testPath)

	err = osFs.Chown(testPath, "root")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not permitted")
}

func TestChmod(t *testing.T) {
	osFs, _ := createOsFs()
	testPath := filepath.Join(os.TempDir(), "ChmodTestDir")

	_, err := os.Create(testPath)
	assert.NoError(t, err)
	defer os.Remove(testPath)

	os.Chmod(testPath, os.FileMode(0666))

	err = osFs.Chmod(testPath, os.FileMode(0644))
	assert.NoError(t, err)

	fileStat, err := os.Stat(testPath)
	assert.NoError(t, err)
	assert.Equal(t, fileStat.Mode(), os.FileMode(0644))
}

func TestWriteToFile(t *testing.T) {
	osFs, _ := createOsFs()
	testPath := filepath.Join(os.TempDir(), "subDir", "WriteToFileTestFile")

	_, err := os.Stat(testPath)
	assert.Error(t, err)

	written, err := osFs.WriteToFile(testPath, "initial write")
	assert.NoError(t, err)
	assert.True(t, written)
	defer os.Remove(testPath)

	file, err := os.Open(testPath)
	assert.NoError(t, err)
	defer file.Close()

	assert.Equal(t, readFile(file), "initial write")

	written, err = osFs.WriteToFile(testPath, "second write")
	assert.NoError(t, err)
	assert.True(t, written)

	file.Close()
	file, err = os.Open(testPath)
	assert.NoError(t, err)

	assert.Equal(t, readFile(file), "second write")

	file.Close()
	file, err = os.Open(testPath)

	written, err = osFs.WriteToFile(testPath, "second write")
	assert.NoError(t, err)
	assert.False(t, written)
	assert.Equal(t, readFile(file), "second write")
}

func TestReadFile(t *testing.T) {
	osFs, _ := createOsFs()
	testPath := filepath.Join(os.TempDir(), "ReadFileTestFile")

	osFs.WriteToFile(testPath, "some contents")
	defer os.Remove(testPath)

	content, err := osFs.ReadFile(testPath)
	assert.NoError(t, err)
	assert.Equal(t, "some contents", content)
}

func TestFileExists(t *testing.T) {
	osFs, _ := createOsFs()
	testPath := filepath.Join(os.TempDir(), "FileExistsTestFile")

	assert.False(t, osFs.FileExists(testPath))

	osFs.WriteToFile(testPath, "initial write")
	defer os.Remove(testPath)

	assert.True(t, osFs.FileExists(testPath))
}

func TestRename(t *testing.T) {
	osFs, _ := createOsFs()
	tempDir := os.TempDir()
	oldPath := filepath.Join(tempDir, "old")
	oldFilePath := filepath.Join(oldPath, "test.txt")
	newPath := filepath.Join(tempDir, "new")

	os.Mkdir(oldPath, os.ModePerm)
	_, err := os.Create(oldFilePath)
	assert.NoError(t, err)

	err = osFs.Rename(oldPath, newPath)
	assert.NoError(t, err)

	assert.True(t, osFs.FileExists(newPath))

	newFilePath := filepath.Join(newPath, "test.txt")
	assert.True(t, osFs.FileExists(newFilePath))
}

func TestSymlink(t *testing.T) {
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
	assert.NoError(t, err)
	assert.Equal(t, os.ModeSymlink, os.ModeSymlink&symlinkStats.Mode())

	symlinkFile, err := os.Open(symlinkPath)
	assert.NoError(t, err)
	assert.Equal(t, "some content", readFile(symlinkFile))
}

func TestSymlinkWhenLinkAlreadyExistsAndLinksToTheIntendedPath(t *testing.T) {
	osFs, _ := createOsFs()
	filePath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1File")
	symlinkPath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1Symlink")

	osFs.WriteToFile(filePath, "some content")
	defer os.Remove(filePath)

	osFs.Symlink(filePath, symlinkPath)
	defer os.Remove(symlinkPath)

	firstSymlinkStats, err := os.Lstat(symlinkPath)
	assert.NoError(t, err)

	err = osFs.Symlink(filePath, symlinkPath)
	assert.NoError(t, err)

	secondSymlinkStats, err := os.Lstat(symlinkPath)
	assert.NoError(t, err)
	assert.Equal(t, firstSymlinkStats.ModTime(), secondSymlinkStats.ModTime())
}

func TestSymlinkWhenLinkAlreadyExistsAndDoesNotLinkToTheIntendedPath(t *testing.T) {
	osFs, _ := createOsFs()
	filePath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1File")
	otherFilePath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1OtherFile")
	symlinkPath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1Symlink")

	osFs.WriteToFile(filePath, "some content")
	defer os.Remove(filePath)

	osFs.WriteToFile(otherFilePath, "other content")
	defer os.Remove(otherFilePath)

	err := osFs.Symlink(otherFilePath, symlinkPath)
	assert.NoError(t, err)

	// Repoints symlink to new destination
	err = osFs.Symlink(filePath, symlinkPath)
	assert.NoError(t, err)

	defer os.Remove(symlinkPath)

	symlinkStats, err := os.Lstat(symlinkPath)
	assert.NoError(t, err)
	assert.Equal(t, os.ModeSymlink, os.ModeSymlink&symlinkStats.Mode())

	symlinkFile, err := os.Open(symlinkPath)
	assert.NoError(t, err)
	assert.Equal(t, "some content", readFile(symlinkFile))
}

func TestSymlinkWhenAFileExistsAtIntendedPath(t *testing.T) {
	osFs, _ := createOsFs()
	filePath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1File")
	symlinkPath := filepath.Join(os.TempDir(), "SymlinkTestIdempotent1Symlink")

	osFs.WriteToFile(filePath, "some content")
	defer os.Remove(filePath)

	osFs.WriteToFile(symlinkPath, "some other content")
	defer os.Remove(symlinkPath)

	// Repoints symlink to new destination
	err := osFs.Symlink(filePath, symlinkPath)
	assert.NoError(t, err)

	defer os.Remove(symlinkPath)

	symlinkStats, err := os.Lstat(symlinkPath)
	assert.NoError(t, err)
	assert.Equal(t, os.ModeSymlink, os.ModeSymlink&symlinkStats.Mode())

	symlinkFile, err := os.Open(symlinkPath)
	assert.NoError(t, err)
	assert.Equal(t, "some content", readFile(symlinkFile))
}

func TestTempFile(t *testing.T) {
	osFs, _ := createOsFs()

	file1, err := osFs.TempFile("fake-prefix")
	assert.NoError(t, err)
	assert.NotEmpty(t, file1)

	defer os.Remove(file1.Name())

	file2, err := osFs.TempFile("fake-prefix")
	assert.NoError(t, err)
	assert.NotEmpty(t, file2)

	defer os.Remove(file2.Name())

	assert.NotEqual(t, file1.Name(), file2.Name())
}

func TestTempDir(t *testing.T) {
	osFs, _ := createOsFs()

	path1, err := osFs.TempDir("fake-prefix")
	assert.NoError(t, err)
	assert.NotEmpty(t, path1)

	defer os.Remove(path1)

	path2, err := osFs.TempDir("fake-prefix")
	assert.NoError(t, err)
	assert.NotEmpty(t, path2)

	defer os.Remove(path2)

	assert.NotEqual(t, path1, path2)
}

func TestCopyDirEntries(t *testing.T) {
	osFs, _ := createOsFs()
	srcPath := "../../../fixtures/test_copy_dir_entries"
	destPath, _ := osFs.TempDir("CopyDirEntriesTestDir")
	defer os.RemoveAll(destPath)

	err := osFs.CopyDirEntries(srcPath, destPath)
	assert.NoError(t, err)

	fooContent, err := osFs.ReadFile(destPath + "/foo.txt")
	assert.NoError(t, err)
	assert.Equal(t, "foo\n", fooContent)

	barContent, err := osFs.ReadFile(destPath + "/bar/bar.txt")
	assert.NoError(t, err)
	assert.Equal(t, "bar\n", barContent)

	assert.True(t, osFs.FileExists(destPath+"/bar/baz"))
}

func TestCopyFile(t *testing.T) {
	osFs, _ := createOsFs()
	srcPath := "../../../fixtures/test_copy_dir_entries/foo.txt"
	dstFile, err := osFs.TempFile("CopyFileTestFile")
	assert.NoError(t, err)
	defer os.Remove(dstFile.Name())

	err = osFs.CopyFile(srcPath, dstFile.Name())

	fooContent, err := osFs.ReadFile(dstFile.Name())
	assert.NoError(t, err)
	assert.Equal(t, fooContent, "foo\n")
}

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
