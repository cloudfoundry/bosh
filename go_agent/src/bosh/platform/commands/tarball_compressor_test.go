package commands_test

import (
	boshlog "bosh/logger"
	. "bosh/platform/commands"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
)

func createdTmpDir(t assert.TestingT, fs boshsys.FileSystem) string {
	dstDir := filepath.Join(os.TempDir(), "TestCompressor")
	err := fs.MkdirAll(dstDir, os.ModePerm)
	assert.NoError(t, err)
	return dstDir
}

func fixtureSrcDir(t assert.TestingT) string {
	pwd, err := os.Getwd()
	assert.NoError(t, err)
	return filepath.Join(pwd, "..", "..", "..", "..", "fixtures", "test_filtered_copy_to_temp")
}

func fixtureSrcTgz(t assert.TestingT) string {
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
func init() {
	Describe("Testing with Ginkgo", func() {
		It("compress files in dir", func() {
			fs, cmdRunner := getCompressorDependencies()
			dc := NewTarballCompressor(cmdRunner, fs)

			srcDir := fixtureSrcDir(GinkgoT())
			tgzName, err := dc.CompressFilesInDir(srcDir)
			assert.NoError(GinkgoT(), err)

			defer os.Remove(tgzName)

			dstDir := createdTmpDir(GinkgoT(), fs)
			defer os.RemoveAll(dstDir)

			_, _, err = cmdRunner.RunCommand("tar", "--no-same-owner", "-xzpf", tgzName, "-C", dstDir)
			assert.NoError(GinkgoT(), err)

			content, err := fs.ReadFile(dstDir + "/app.stdout.log")
			assert.NoError(GinkgoT(), err)
			assert.Contains(GinkgoT(), content, "this is app stdout")

			content, err = fs.ReadFile(dstDir + "/app.stderr.log")
			assert.NoError(GinkgoT(), err)
			assert.Contains(GinkgoT(), content, "this is app stderr")

			content, err = fs.ReadFile(dstDir + "/other_logs/other_app.stdout.log")
			assert.NoError(GinkgoT(), err)
			assert.Contains(GinkgoT(), content, "this is other app stdout")
		})
		It("decompress file to dir", func() {

			fs, cmdRunner := getCompressorDependencies()
			dc := NewTarballCompressor(cmdRunner, fs)

			dstDir := createdTmpDir(GinkgoT(), fs)
			defer os.RemoveAll(dstDir)

			err := dc.DecompressFileToDir(fixtureSrcTgz(GinkgoT()), dstDir)
			assert.NoError(GinkgoT(), err)

			content, err := fs.ReadFile(dstDir + "/not-nested-file")
			assert.NoError(GinkgoT(), err)
			assert.Contains(GinkgoT(), content, "not-nested-file")

			content, err = fs.ReadFile(dstDir + "/dir/nested-file")
			assert.NoError(GinkgoT(), err)
			assert.Contains(GinkgoT(), content, "nested-file")

			content, err = fs.ReadFile(dstDir + "/dir/nested-dir/double-nested-file")
			assert.NoError(GinkgoT(), err)
			assert.Contains(GinkgoT(), content, "double-nested-file")

			content, err = fs.ReadFile(dstDir + "/empty-dir")
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "is a directory")

			content, err = fs.ReadFile(dstDir + "/dir/empty-nested-dir")
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "is a directory")
		})
		It("decompress file to dir returns error", func() {

			nonExistentDstDir := filepath.Join(os.TempDir(), "TestDecompressFileToDirReturnsError")

			fs, cmdRunner := getCompressorDependencies()
			dc := NewTarballCompressor(cmdRunner, fs)

			err := dc.DecompressFileToDir(fixtureSrcTgz(GinkgoT()), nonExistentDstDir)
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), nonExistentDstDir)
		})
		It("decompress file to dir uses no same owner option", func() {

			fs, _ := getCompressorDependencies()
			cmdRunner := fakesys.NewFakeCmdRunner()
			dc := NewTarballCompressor(cmdRunner, fs)

			dstDir := createdTmpDir(GinkgoT(), fs)
			defer os.RemoveAll(dstDir)

			tarballPath := fixtureSrcTgz(GinkgoT())
			err := dc.DecompressFileToDir(tarballPath, dstDir)
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), 1, len(cmdRunner.RunCommands))
			assert.Equal(GinkgoT(), []string{
				"tar", "--no-same-owner",
				"-xzvf", tarballPath,
				"-C", dstDir,
			}, cmdRunner.RunCommands[0])
		})
	})
}
