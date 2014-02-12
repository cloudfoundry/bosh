package commands_test

import (
	boshlog "bosh/logger"
	. "bosh/platform/commands"
	boshsys "bosh/system"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
)

func copierFixtureSrcDir(t assert.TestingT) string {
	pwd, err := os.Getwd()
	assert.NoError(t, err)
	return filepath.Join(pwd, "..", "..", "..", "..", "fixtures", "test_filtered_copy_to_temp")
}

func getCopierDependencies() (boshsys.FileSystem, boshsys.CmdRunner) {
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
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
			assert.NoError(GinkgoT(), err)
			defer os.RemoveAll(dstDir)

			tarDirStat, err := os.Stat(dstDir)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), os.FileMode(0755), tarDirStat.Mode().Perm())

			content, err := fs.ReadFile(dstDir + "/app.stdout.log")
			assert.NoError(GinkgoT(), err)
			assert.Contains(GinkgoT(), content, "this is app stdout")

			content, err = fs.ReadFile(dstDir + "/app.stderr.log")
			assert.NoError(GinkgoT(), err)
			assert.Contains(GinkgoT(), content, "this is app stderr")

			content, err = fs.ReadFile(dstDir + "/other_logs/other_app.stdout.log")
			assert.NoError(GinkgoT(), err)
			assert.Contains(GinkgoT(), content, "this is other app stdout")

			content, err = fs.ReadFile(dstDir + "/other_logs/more_logs/more.stdout.log")
			assert.NoError(GinkgoT(), err)
			assert.Contains(GinkgoT(), content, "this is more stdout")

			assert.True(GinkgoT(), fs.FileExists(dstDir+"/some_directory"))
			assert.True(GinkgoT(), fs.FileExists(dstDir+"/some_directory/sub_dir"))
			assert.True(GinkgoT(), fs.FileExists(dstDir+"/some_directory/sub_dir/other_sub_dir"))

			content, err = fs.ReadFile(dstDir + "/other_logs/other_app.stderr.log")
			assert.Error(GinkgoT(), err)

			content, err = fs.ReadFile(dstDir + "/../some.config")
			assert.Error(GinkgoT(), err)
		})
		It("clean up", func() {

			fs, cmdRunner := getCopierDependencies()
			dc := NewCpCopier(cmdRunner, fs)

			tempDir := filepath.Join(os.TempDir(), "test-copier-cleanup")
			fs.MkdirAll(tempDir, os.ModePerm)
			dc.CleanUp(tempDir)

			_, err := os.Stat(tempDir)
			assert.Error(GinkgoT(), err)
		})
	})
}
