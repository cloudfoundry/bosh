package commands

import (
	boshlog "bosh/logger"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"
)

func TestCompressFilesInDir(t *testing.T) {
	fs, cmdRunner := getCompressorDependencies()
	dc := NewTarballCompressor(cmdRunner, fs)

	srcDir := fixtureSrcDir(t)
	tgzName, err := dc.CompressFilesInDir(srcDir)
	assert.NoError(t, err)

	defer os.Remove(tgzName)

	dstDir := createdTmpDir(t, fs)
	defer os.RemoveAll(dstDir)

	_, _, err = cmdRunner.RunCommand("tar", "--no-same-owner", "-xzpf", tgzName, "-C", dstDir)
	assert.NoError(t, err)

	tarDirStat, err := os.Stat(dstDir)
	assert.NoError(t, err)
	assert.Equal(t, os.FileMode(0755), tarDirStat.Mode().Perm())

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
}

func TestDecompressFileToDir(t *testing.T) {
	fs, cmdRunner := getCompressorDependencies()
	dc := NewTarballCompressor(cmdRunner, fs)

	dstDir := createdTmpDir(t, fs)
	defer os.RemoveAll(dstDir)

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
	assert.Contains(t, err.Error(), nonExistentDstDir) // path in error
}

func TestDecompressFileToDirUsesNoSameOwnerOption(t *testing.T) {
	fs, _ := getCompressorDependencies()
	cmdRunner := fakesys.NewFakeCmdRunner()
	dc := NewTarballCompressor(cmdRunner, fs)

	dstDir := createdTmpDir(t, fs)
	defer os.RemoveAll(dstDir)

	tarballPath := fixtureSrcTgz(t)
	err := dc.DecompressFileToDir(tarballPath, dstDir)
	assert.NoError(t, err)

	assert.Equal(t, 1, len(cmdRunner.RunCommands))
	assert.Equal(t, []string{
		"tar", "--no-same-owner",
		"-xzvf", tarballPath,
		"-C", dstDir,
	}, cmdRunner.RunCommands[0])
}

func createdTmpDir(t *testing.T, fs boshsys.FileSystem) string {
	dstDir := filepath.Join(os.TempDir(), "TestCompressor")
	err := fs.MkdirAll(dstDir, os.ModePerm)
	assert.NoError(t, err)
	return dstDir
}

func fixtureSrcDir(t *testing.T) string {
	pwd, err := os.Getwd()
	assert.NoError(t, err)
	return filepath.Join(pwd, "..", "..", "..", "..", "fixtures", "test_filtered_copy_to_temp")
}

func fixtureSrcTgz(t *testing.T) string {
	pwd, err := os.Getwd()
	assert.NoError(t, err)
	return filepath.Join(pwd, "..", "..", "..", "..", "fixtures", "compressor-decompress-file-to-dir.tgz")
}

func getCompressorDependencies() (boshsys.FileSystem, boshsys.CmdRunner) {
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	cmdRunner := boshsys.NewExecCmdRunner(logger)
	fs := boshsys.NewOsFileSystem(logger, cmdRunner)
	return fs, cmdRunner
}
