package commands_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	boshlog "bosh/logger"
	. "bosh/platform/commands"
	boshsys "bosh/system"
)

func copierFixtureSrcDir(t assert.TestingT) string {
	pwd, err := os.Getwd()
	assert.NoError(t, err)
	return filepath.Join(pwd, "..", "..", "..", "..", "fixtures", "test_filtered_copy_to_temp")
}

func getCopierDependencies() (boshsys.FileSystem, boshsys.CmdRunner) {
	logger := boshlog.NewLogger(boshlog.LevelNone)
	cmdRunner := boshsys.NewExecCmdRunner(logger)
	fs := boshsys.NewOsFileSystem(logger, cmdRunner)
	return fs, cmdRunner
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("filtered copy to temp", func() {
			fs, cmdRunner := getCopierDependencies()
			dc := NewCpCopier(cmdRunner, fs)

			srcDir := copierFixtureSrcDir(GinkgoT())
			dstDir, err := dc.FilteredCopyToTemp(srcDir, []string{"**/*.stdout.log", "*.stderr.log", "../some.config", "some_directory/**/*"})
			Expect(err).ToNot(HaveOccurred())
			defer os.RemoveAll(dstDir)

			tarDirStat, err := os.Stat(dstDir)
			Expect(err).ToNot(HaveOccurred())
			Expect(os.FileMode(0755)).To(Equal(tarDirStat.Mode().Perm()))

			content, err := fs.ReadFileString(dstDir + "/app.stdout.log")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "this is app stdout")

			content, err = fs.ReadFileString(dstDir + "/app.stderr.log")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "this is app stderr")

			content, err = fs.ReadFileString(dstDir + "/other_logs/other_app.stdout.log")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "this is other app stdout")

			content, err = fs.ReadFileString(dstDir + "/other_logs/more_logs/more.stdout.log")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "this is more stdout")

			Expect(fs.FileExists(dstDir + "/some_directory")).To(BeTrue())
			Expect(fs.FileExists(dstDir + "/some_directory/sub_dir")).To(BeTrue())
			Expect(fs.FileExists(dstDir + "/some_directory/sub_dir/other_sub_dir")).To(BeTrue())

			_, err = fs.ReadFile(dstDir + "/other_logs/other_app.stderr.log")
			Expect(err).To(HaveOccurred())

			_, err = fs.ReadFile(dstDir + "/../some.config")
			Expect(err).To(HaveOccurred())
		})
		It("clean up", func() {

			fs, cmdRunner := getCopierDependencies()
			dc := NewCpCopier(cmdRunner, fs)

			tempDir := filepath.Join(os.TempDir(), "test-copier-cleanup")
			fs.MkdirAll(tempDir, os.ModePerm)
			dc.CleanUp(tempDir)

			_, err := os.Stat(tempDir)
			Expect(err).To(HaveOccurred())
		})
	})
}
