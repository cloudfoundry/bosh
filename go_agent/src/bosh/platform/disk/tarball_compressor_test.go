package disk

import (
	boshlog "bosh/logger"
	boshsys "bosh/system"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"
)

func TestCompressFilesInDir(t *testing.T) {
	fs, cmdRunner := getCompressorDependencies()
	dc := NewTarballCompressor(cmdRunner, fs)

	srcDir := fixtureSrcDir(t)
	tgz, err := dc.CompressFilesInDir(srcDir, []string{"**/*.stdout.log", "*.stderr.log", "../some.config"})
	assert.NoError(t, err)

	defer os.Remove(tgz.Name())

	dstDir := createdTmpDir(t, fs)
	defer os.RemoveAll(dstDir)

	_, _, err = cmdRunner.RunCommand("tar", "xzf", tgz.Name(), "-C", dstDir)
	assert.NoError(t, err)

	// regular files
	content, err := fs.ReadFile(dstDir + "/app.stdout.log")
	assert.NoError(t, err)
	assert.Contains(t, content, "this is app stdout")

	content, err = fs.ReadFile(dstDir + "/app.stderr.log")
	assert.NoError(t, err)
	assert.Contains(t, content, "this is app stderr")

	// file in a directory
	content, err = fs.ReadFile(dstDir + "/other_logs/other_app.stdout.log")
	assert.NoError(t, err)
	assert.Contains(t, content, "this is other app stdout")

	// file that is not matching filter
	content, err = fs.ReadFile(dstDir + "/other_logs/other_app.stderr.log")
	assert.Error(t, err)

	content, err = fs.ReadFile(dstDir + "/../some.config")
	assert.Error(t, err)
}

func TestDecompressFileToDir(t *testing.T) {
	fs, cmdRunner := getCompressorDependencies()
	dstDir := createdTmpDir(t, fs)
	defer os.RemoveAll(dstDir)

	dc := NewTarballCompressor(cmdRunner, fs)

	err := dc.DecompressFileToDir(fixtureSrcTgz(t), dstDir)
	assert.NoError(t, err)

	// regular files
	content, err := fs.ReadFile(dstDir + "/not-nested-file")
	assert.NoError(t, err)
	assert.Contains(t, content, "not-nested-file")

	// nested directory with a file
	content, err = fs.ReadFile(dstDir + "/dir/nested-file")
	assert.NoError(t, err)
	assert.Contains(t, content, "nested-file")

	// nested directory with a file inside another directory
	content, err = fs.ReadFile(dstDir + "/dir/nested-dir/double-nested-file")
	assert.NoError(t, err)
	assert.Contains(t, content, "double-nested-file")

	// directory without a file (empty)
	content, err = fs.ReadFile(dstDir + "/empty-dir")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "is a directory")

	// nested directory without a file (empty) inside another directory
	content, err = fs.ReadFile(dstDir + "/dir/empty-nested-dir")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "is a directory")
}

func TestDecompressFileToDirReturnsError(t *testing.T) {
	nonExistentDstDir := filepath.Join(os.TempDir(), "TestDecompressFileToDirReturnsError")

	fs, cmdRunner := getCompressorDependencies()
	dc := NewTarballCompressor(cmdRunner, fs)

	// propagates errors raised when untarring
	err := dc.DecompressFileToDir(fixtureSrcTgz(t), nonExistentDstDir)
	assert.Error(t, err)

	// path is in the error message
	assert.Contains(t, err.Error(), nonExistentDstDir)
}

func createdTmpDir(t *testing.T, fs boshsys.FileSystem) (dstDir string) {
	dstDir = filepath.Join(os.TempDir(), "TestCompressor")
	err := fs.MkdirAll(dstDir, os.ModePerm)
	assert.NoError(t, err)

	return
}

func fixtureSrcDir(t *testing.T) (srcDir string) {
	pwd, err := os.Getwd()
	assert.NoError(t, err)

	srcDir = filepath.Join(pwd, "..", "..", "..", "..", "fixtures", "test_get_files_in_dir")
	return
}

func fixtureSrcTgz(t *testing.T) (srcTgz *os.File) {
	pwd, err := os.Getwd()
	assert.NoError(t, err)

	srcTgz, err = os.Open(filepath.Join(pwd, "..", "..", "..", "..", "fixtures", "compressor-decompress-file-to-dir.tgz"))
	assert.NoError(t, err)

	return
}

func getCompressorDependencies() (fs boshsys.FileSystem, cmdRunner boshsys.CmdRunner) {
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)

	fs = boshsys.NewOsFileSystem(logger)
	cmdRunner = boshsys.NewExecCmdRunner(logger)
	return
}
