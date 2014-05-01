package commands_test

import (
	"errors"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	boshlog "bosh/logger"
	. "bosh/platform/commands"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
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
	logger := boshlog.NewLogger(boshlog.LevelNone)
	cmdRunner := boshsys.NewExecCmdRunner(logger)
	fs := boshsys.NewOsFileSystem(logger)
	return fs, cmdRunner
}

func init() {
	Describe("Testing with Ginkgo", func() {
		It("compress files in dir", func() {
			fs, cmdRunner := getCompressorDependencies()
			dc := NewTarballCompressor(cmdRunner, fs)

			srcDir := fixtureSrcDir(GinkgoT())
			tgzName, err := dc.CompressFilesInDir(srcDir)
			Expect(err).ToNot(HaveOccurred())

			defer os.Remove(tgzName)

			dstDir := createdTmpDir(GinkgoT(), fs)
			defer os.RemoveAll(dstDir)

			_, _, _, err = cmdRunner.RunCommand("tar", "--no-same-owner", "-xzpf", tgzName, "-C", dstDir)
			Expect(err).ToNot(HaveOccurred())

			content, err := fs.ReadFileString(dstDir + "/app.stdout.log")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "this is app stdout")

			content, err = fs.ReadFileString(dstDir + "/app.stderr.log")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "this is app stderr")

			content, err = fs.ReadFileString(dstDir + "/other_logs/other_app.stdout.log")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "this is other app stdout")
		})

		It("decompress file to dir", func() {
			fs, cmdRunner := getCompressorDependencies()
			dc := NewTarballCompressor(cmdRunner, fs)

			dstDir := createdTmpDir(GinkgoT(), fs)
			defer os.RemoveAll(dstDir)

			err := dc.DecompressFileToDir(fixtureSrcTgz(GinkgoT()), dstDir)
			Expect(err).ToNot(HaveOccurred())

			content, err := fs.ReadFileString(dstDir + "/not-nested-file")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "not-nested-file")

			content, err = fs.ReadFileString(dstDir + "/dir/nested-file")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "nested-file")

			content, err = fs.ReadFileString(dstDir + "/dir/nested-dir/double-nested-file")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "double-nested-file")

			content, err = fs.ReadFileString(dstDir + "/empty-dir")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("is a directory"))

			content, err = fs.ReadFileString(dstDir + "/dir/empty-nested-dir")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("is a directory"))
		})

		It("decompress file to dir returns error", func() {
			nonExistentDstDir := filepath.Join(os.TempDir(), "TestDecompressFileToDirReturnsError")

			fs, cmdRunner := getCompressorDependencies()
			dc := NewTarballCompressor(cmdRunner, fs)

			err := dc.DecompressFileToDir(fixtureSrcTgz(GinkgoT()), nonExistentDstDir)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring(nonExistentDstDir))
		})

		It("decompress file to dir uses no same owner option", func() {
			fs, _ := getCompressorDependencies()
			cmdRunner := fakesys.NewFakeCmdRunner()
			dc := NewTarballCompressor(cmdRunner, fs)

			dstDir := createdTmpDir(GinkgoT(), fs)
			defer os.RemoveAll(dstDir)

			tarballPath := fixtureSrcTgz(GinkgoT())
			err := dc.DecompressFileToDir(tarballPath, dstDir)
			Expect(err).ToNot(HaveOccurred())

			Expect(1).To(Equal(len(cmdRunner.RunCommands)))
			assert.Equal(GinkgoT(), []string{
				"tar", "--no-same-owner",
				"-xzvf", tarballPath,
				"-C", dstDir,
			}, cmdRunner.RunCommands[0])
		})

		Describe("CleanUp", func() {
			It("removes tarball path", func() {
				_, cmdRunner := getCompressorDependencies()
				fs := fakesys.NewFakeFileSystem()
				dc := NewTarballCompressor(cmdRunner, fs)

				err := fs.WriteFileString("/fake-tarball.tar", "")
				Expect(err).ToNot(HaveOccurred())

				err = dc.CleanUp("/fake-tarball.tar")
				Expect(err).ToNot(HaveOccurred())

				Expect(fs.FileExists("/fake-tarball.tar")).To(BeFalse())
			})

			It("returns error if removing tarball path fails", func() {
				_, cmdRunner := getCompressorDependencies()
				fs := fakesys.NewFakeFileSystem()
				dc := NewTarballCompressor(cmdRunner, fs)

				fs.RemoveAllError = errors.New("fake-remove-all-err")

				err := dc.CleanUp("/fake-tarball.tar")
				Expect(err).To(MatchError("fake-remove-all-err"))
			})
		})
	})
}
