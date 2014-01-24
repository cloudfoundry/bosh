package blobstore

import (
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestFetch(t *testing.T) {
	blobManager, fs := createBlobManager()
	fs.WriteToFile("/var/vcap/micro_bosh/data/cache/105d33ae-655c-493d-bf9f-1df5cf3ca847", "some data")

	blobBytes, err := blobManager.Fetch("105d33ae-655c-493d-bf9f-1df5cf3ca847")
	assert.NoError(t, err)
	assert.Equal(t, blobBytes, []byte("some data"))
}

func TestWrite(t *testing.T) {
	blobManager, fs := createBlobManager()
	fs.WriteToFile("/var/vcap/micro_bosh/data/cache/105d33ae-655c-493d-bf9f-1df5cf3ca847", "some data")

	err := blobManager.Write("105d33ae-655c-493d-bf9f-1df5cf3ca847", []byte("new data"))
	assert.NoError(t, err)

	contents, err := fs.ReadFile("/var/vcap/micro_bosh/data/cache/105d33ae-655c-493d-bf9f-1df5cf3ca847")
	assert.NoError(t, err)
	assert.Equal(t, contents, "new data")
}

func createBlobManager() (blobManager BlobManager, fs *fakesys.FakeFileSystem) {
	fs = fakesys.NewFakeFileSystem()
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")

	blobManager = NewBlobManager(fs, dirProvider)
	return
}
