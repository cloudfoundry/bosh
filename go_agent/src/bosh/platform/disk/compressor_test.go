package disk

import (
	boshsys "bosh/system"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"
)

func TestCompressFilesInDir(t *testing.T) {
	fs := boshsys.NewOsFileSystem()

	tmpDir := filepath.Join(os.TempDir(), "TestCompressFilesInDir")
	err := fs.MkdirAll(tmpDir, os.ModePerm)
	assert.NoError(t, err)

	defer os.RemoveAll(tmpDir)

	execCmdRunner := boshsys.NewExecCmdRunner()
	dc := NewCompressor(execCmdRunner, fs)

	pwd, err := os.Getwd()
	assert.NoError(t, err)

	fixturesDir := filepath.Join(pwd, "..", "..", "..", "..", "fixtures", "test_get_files_in_dir")
	tgz, err := dc.CompressFilesInDir(fixturesDir, []string{"**/*.stdout.log", "*.stderr.log", "../some.config"})
	assert.NoError(t, err)

	defer os.Remove(tgz.Name())

	_, _, err = execCmdRunner.RunCommand("tar", "xzf", tgz.Name(), "-C", tmpDir)
	assert.NoError(t, err)

	content, err := fs.ReadFile(tmpDir + "/app.stdout.log")
	assert.NoError(t, err)
	assert.Contains(t, content, "this is app stdout")

	content, err = fs.ReadFile(tmpDir + "/app.stderr.log")
	assert.NoError(t, err)
	assert.Contains(t, content, "this is app stderr")

	content, err = fs.ReadFile(tmpDir + "/other_logs/other_app.stdout.log")
	assert.NoError(t, err)
	assert.Contains(t, content, "this is other app stdout")

	content, err = fs.ReadFile(tmpDir + "/other_logs/other_app.stderr.log")
	assert.Error(t, err)

	content, err = fs.ReadFile(tmpDir + "/../some.config")
	assert.Error(t, err)
}
