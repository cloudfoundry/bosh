package blobstore

import (
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestFetch(t *testing.T) {
	fs := fakesys.NewFakeFileSystem()
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")

	blobFetcher := NewBlobFetcher(fs, dirProvider)

	fs.WriteToFile("/var/vcap/micro_bosh/data/cache/105d33ae-655c-493d-bf9f-1df5cf3ca847", "some data")

	blobBytes, err := blobFetcher.Fetch("105d33ae-655c-493d-bf9f-1df5cf3ca847")
	assert.NoError(t, err)
	assert.Equal(t, blobBytes, []byte("some data"))
}
