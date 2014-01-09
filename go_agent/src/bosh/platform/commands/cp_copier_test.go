package commands

import (
	boshlog "bosh/logger"
	boshsys "bosh/system"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"
)

func TestFilteredCopyToTemp(t *testing.T) {
	fs, cmdRunner := getCopierDependencies()
	dc := NewCpCopier(cmdRunner, fs)

	srcDir := copierFixtureSrcDir(t)
	dstDir, err := dc.FilteredCopyToTemp(srcDir, []string{"**/*.stdout.log", "*.stderr.log", "../some.config", "some_directory/**/*"})
	assert.NoError(t, err)
	defer os.RemoveAll(dstDir)

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

	// file in a sub directory
	content, err = fs.ReadFile(dstDir + "/other_logs/more_logs/more.stdout.log")
	assert.NoError(t, err)
	assert.Contains(t, content, "this is more stdout")

	// directories
	assert.True(t, fs.FileExists(dstDir+"/some_directory"))
	assert.True(t, fs.FileExists(dstDir+"/some_directory/sub_dir"))
	assert.True(t, fs.FileExists(dstDir+"/some_directory/sub_dir/other_sub_dir"))

	// file that is not matching filter
	content, err = fs.ReadFile(dstDir + "/other_logs/other_app.stderr.log")
	assert.Error(t, err)

	content, err = fs.ReadFile(dstDir + "/../some.config")
	assert.Error(t, err)
}

func TestCleanUp(t *testing.T) {
	fs, cmdRunner := getCopierDependencies()
	dc := NewCpCopier(cmdRunner, fs)

	tempDir := filepath.Join(os.TempDir(), "test-copier-cleanup")
	fs.MkdirAll(tempDir, os.ModePerm)
	dc.CleanUp(tempDir)

	_, err := os.Stat(tempDir)
	assert.Error(t, err)
}

func copierFixtureSrcDir(t *testing.T) string {
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
