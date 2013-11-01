package system

import (
	"bytes"
	"github.com/stretchr/testify/assert"
	"io"
	"os"
	"path/filepath"
	"testing"
)

func TestHomeDir(t *testing.T) {
	osFs := OsFileSystem{}

	homeDir, err := osFs.HomeDir("root")
	assert.NoError(t, err)
	assert.Contains(t, homeDir, "/root")
}

func TestMkdirAll(t *testing.T) {
	osFs := OsFileSystem{}
	tmpPath := os.TempDir()
	testPath := filepath.Join(tmpPath, "foo", "bar", "baz")
	defer os.RemoveAll(filepath.Join(tmpPath, "foo"))

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
}

func TestChown(t *testing.T) {
	osFs := OsFileSystem{}
	testPath := filepath.Join(os.TempDir(), "foo")

	err := os.Mkdir(testPath, os.FileMode(0700))
	assert.NoError(t, err)
	defer os.RemoveAll(testPath)

	err = osFs.Chown(testPath, "root")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "not permitted")
}

func TestChmod(t *testing.T) {
	osFs := OsFileSystem{}
	testPath := filepath.Join(os.TempDir(), "foo")

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
	osFs := OsFileSystem{}
	testPath := filepath.Join(os.TempDir(), "foo")

	_, err := os.Stat(testPath)
	assert.Error(t, err)

	err = osFs.WriteToFile(testPath, "initial write")
	assert.NoError(t, err)
	defer os.Remove(testPath)

	file, err := os.Open(testPath)
	assert.NoError(t, err)
	defer file.Close()

	assert.Equal(t, readFile(file), "initial write")

	err = osFs.WriteToFile(testPath, "second write")
	assert.NoError(t, err)

	file.Close()
	file, err = os.Open(testPath)
	assert.NoError(t, err)

	assert.Equal(t, readFile(file), "second write")
}

func readFile(file *os.File) string {
	buf := &bytes.Buffer{}
	_, err := io.Copy(buf, file)

	if err != nil {
		return ""
	}

	return string(buf.Bytes())
}
