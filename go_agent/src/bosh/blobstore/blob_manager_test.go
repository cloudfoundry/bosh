package blobstore_test

import (
	. "bosh/blobstore"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func createBlobManager() (blobManager BlobManager, fs *fakesys.FakeFileSystem) {
	fs = fakesys.NewFakeFileSystem()
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")

	blobManager = NewBlobManager(fs, dirProvider)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("fetch", func() {
			blobManager, fs := createBlobManager()
			fs.WriteToFile("/var/vcap/micro_bosh/data/cache/105d33ae-655c-493d-bf9f-1df5cf3ca847", "some data")

			blobBytes, err := blobManager.Fetch("105d33ae-655c-493d-bf9f-1df5cf3ca847")
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), blobBytes, []byte("some data"))
		})
		It("write", func() {

			blobManager, fs := createBlobManager()
			fs.WriteToFile("/var/vcap/micro_bosh/data/cache/105d33ae-655c-493d-bf9f-1df5cf3ca847", "some data")

			err := blobManager.Write("105d33ae-655c-493d-bf9f-1df5cf3ca847", []byte("new data"))
			assert.NoError(GinkgoT(), err)

			contents, err := fs.ReadFile("/var/vcap/micro_bosh/data/cache/105d33ae-655c-493d-bf9f-1df5cf3ca847")
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), contents, "new data")
		})
	})
}
