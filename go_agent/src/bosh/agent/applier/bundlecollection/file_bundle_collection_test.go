package bundlecollection

import (
	fakesys "bosh/system/fakes"
	"errors"
	"github.com/stretchr/testify/assert"
	"os"
	"testing"
)

const expectedInstallPath = "/fake-collection-path/data/fake-collection-name/fake-bundle-name/fake-bundle-version"
const expectedEnablePath = "/fake-collection-path/fake-collection-name/fake-bundle-name"
const expectedEnableDirname = "/fake-collection-path/fake-collection-name"

func TestInstall(t *testing.T) {
	fs, fileCollection, bundle := buildFileBundleCollection()

	actualFs, path, err := fileCollection.Install(bundle)
	assert.NoError(t, err)
	assert.Equal(t, fs, actualFs)
	assert.Equal(t, expectedInstallPath, path)
	assert.True(t, fs.FileExists(expectedInstallPath))

	// directory is created with proper permissions
	fileStats := fs.GetFileTestStat(expectedInstallPath)
	assert.NotNil(t, fileStats)
	assert.Equal(t, fakesys.FakeFileTypeDir, fileStats.FileType)
	assert.Equal(t, os.FileMode(0755), fileStats.FileMode)

	// check idempotency
	_, _, err = fileCollection.Install(bundle)
	assert.NoError(t, err)
}

func TestInstallErrsWhenBundleIsMissingInfo(t *testing.T) {
	_, fileCollection, _ := buildFileBundleCollection()

	_, _, err := fileCollection.Install(testBundle{
		Name:    "",
		Version: "fake-bundle-version",
	})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "missing bundle name")

	_, _, err = fileCollection.Install(testBundle{
		Name:    "fake-bundle-name",
		Version: "",
	})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "missing bundle version")
}

func TestInstallErrsWhenBundleCannotBeInstalled(t *testing.T) {
	fs, fileCollection, bundle := buildFileBundleCollection()

	fs.MkdirAllError = errors.New("fake-mkdirall-error")

	_, _, err := fileCollection.Install(bundle)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-mkdirall-error")
}

func TestGetDir(t *testing.T) {
	fs, fileCollection, bundle := buildFileBundleCollection()

	fs.MkdirAll(expectedInstallPath, os.FileMode(0))

	actualFs, path, err := fileCollection.GetDir(bundle)
	assert.NoError(t, err)
	assert.Equal(t, fs, actualFs)
	assert.Equal(t, expectedInstallPath, path)
}

func TestGetDirErrsWhenDirDoesNotExist(t *testing.T) {
	_, fileCollection, bundle := buildFileBundleCollection()

	_, _, err := fileCollection.GetDir(bundle)
	assert.Error(t, err)
}

func TestEnableSucceedsWhenBundleIsInstalled(t *testing.T) {
	fs, fileCollection, bundle := buildFileBundleCollection()

	_, _, err := fileCollection.Install(bundle)
	assert.NoError(t, err)

	err = fileCollection.Enable(bundle)
	assert.NoError(t, err)

	// symlink exists
	fileStats := fs.GetFileTestStat(expectedEnablePath)
	assert.NotNil(t, fileStats)
	assert.Equal(t, fakesys.FakeFileTypeSymlink, fileStats.FileType)
	assert.Equal(t, expectedInstallPath, fileStats.SymlinkTarget)

	// enable directory is created
	fileStats = fs.GetFileTestStat(expectedEnableDirname)
	assert.NotNil(t, fileStats)
	assert.Equal(t, fakesys.FakeFileTypeDir, fileStats.FileType)
	assert.Equal(t, os.FileMode(0755), fileStats.FileMode)

	// check idempotency
	err = fileCollection.Enable(bundle)
	assert.NoError(t, err)
}

func TestEnableErrsWhenBundleIsMissingInfo(t *testing.T) {
	_, fileCollection, _ := buildFileBundleCollection()

	err := fileCollection.Enable(testBundle{
		Name:    "",
		Version: "fake-bundle-version",
	})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "missing bundle name")

	err = fileCollection.Enable(testBundle{
		Name:    "fake-bundle-name",
		Version: "",
	})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "missing bundle version")
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

func TestEnableErrsWhenCannotCreateEnableDir(t *testing.T) {
	fs, fileCollection, bundle := buildFileBundleCollection()

	_, _, err := fileCollection.Install(bundle)
	assert.NoError(t, err)

	fs.MkdirAllError = errors.New("fake-mkdirall-error")

	err = fileCollection.Enable(bundle)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-mkdirall-error")
}

func TestEnableErrsWhenBundleCannotBeEnabled(t *testing.T) {
	fs, fileCollection, bundle := buildFileBundleCollection()

	_, _, err := fileCollection.Install(bundle)
	assert.NoError(t, err)

	fs.SymlinkError = errors.New("fake-symlink-error")

	err = fileCollection.Enable(bundle)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake-symlink-error")
}

func buildFileBundleCollection() (*fakesys.FakeFileSystem, *FileBundleCollection, testBundle) {
	fs := &fakesys.FakeFileSystem{}

	fileCollection := NewFileBundleCollection("/fake-collection-path/data", "/fake-collection-path",
		"fake-collection-name", fs)

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
