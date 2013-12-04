package bundlecollection

import (
	fakesys "bosh/system/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

const expectedInstallPath = "/fake-collection-path/data/fake-collection-name/fake-bundle-name/fake-bundle-version"
const expectedEnablePath = "/fake-collection-path/fake-collection-name/fake-bundle-name"

func TestInstall(t *testing.T) {
	fs, fileCollection, bundle := buildFileBundleCollection()

	// directory is created
	path, err := fileCollection.Install(bundle)
	assert.NoError(t, err)
	assert.Equal(t, path, expectedInstallPath)
	assert.True(t, fs.FileExists(expectedInstallPath))

	// check idempotency
	_, err = fileCollection.Install(bundle)
	assert.NoError(t, err)
}

func TestInstallErrsWhenBundleCannotBeInstalled(t *testing.T) {
	fs, fileCollection, bundle := buildFileBundleCollection()

	fs.MkdirAllError = errors.New("fake-mkdirall-error")

	// directory is created
	_, err := fileCollection.Install(bundle)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-mkdirall-error")
}

func TestEnableSucceedsWhenBundleIsInstalled(t *testing.T) {
	fs, fileCollection, bundle := buildFileBundleCollection()

	_, err := fileCollection.Install(bundle)
	assert.NoError(t, err)

	err = fileCollection.Enable(bundle)
	assert.NoError(t, err)

	// symlink exists
	fileStats := fs.GetFileTestStat(expectedEnablePath)
	assert.NotNil(t, fileStats)
	assert.Equal(t, fakesys.FakeFileTypeSymlink, fileStats.FileType)
	assert.Equal(t, expectedInstallPath, fileStats.SymlinkTarget)

	// check idempotency
	err = fileCollection.Enable(bundle)
	assert.NoError(t, err)
}

func TestEnableErrsWhenBundleIsNotInstalled(t *testing.T) {
	fs, fileCollection, bundle := buildFileBundleCollection()

	err := fileCollection.Enable(bundle)
	assert.Error(t, err)
	assert.Equal(t, "bundle must be installed", err.Error())

	// symlink does not exist
	fileStats := fs.GetFileTestStat(expectedEnablePath)
	assert.Nil(t, fileStats)
}

func TestEnableErrsWhenBundleCannotBeEnabled(t *testing.T) {
	fs, fileCollection, bundle := buildFileBundleCollection()

	_, err := fileCollection.Install(bundle)
	assert.NoError(t, err)

	fs.SymlinkError = errors.New("fake-symlink-error")

	err = fileCollection.Enable(bundle)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-symlink-error")
}

func buildFileBundleCollection() (*fakesys.FakeFileSystem, *FileBundleCollection, testBundle) {
	fs := &fakesys.FakeFileSystem{}

	fileCollection := NewFileBundleCollection("fake-collection-name", "/fake-collection-path", fs)

	bundle := testBundle{
		Name:    "fake-bundle-name",
		Version: "fake-bundle-version",
	}

	return fs, fileCollection, bundle
}

type testBundle struct {
	Name    string
	Version string
}

func (s testBundle) BundleName() string    { return s.Name }
func (s testBundle) BundleVersion() string { return s.Version }
