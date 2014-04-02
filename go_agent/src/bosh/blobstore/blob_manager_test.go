package blobstore_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/blobstore"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
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
			fs.WriteFileString("/var/vcap/micro_bosh/data/cache/105d33ae-655c-493d-bf9f-1df5cf3ca847", "some data")

			blobBytes, err := blobManager.Fetch("105d33ae-655c-493d-bf9f-1df5cf3ca847")
			Expect(err).ToNot(HaveOccurred())
			Expect(string(blobBytes)).To(Equal("some data"))
		})
		It("write", func() {

			blobManager, fs := createBlobManager()
			fs.WriteFileString("/var/vcap/micro_bosh/data/cache/105d33ae-655c-493d-bf9f-1df5cf3ca847", "some data")

			err := blobManager.Write("105d33ae-655c-493d-bf9f-1df5cf3ca847", []byte("new data"))
			Expect(err).ToNot(HaveOccurred())

			contents, err := fs.ReadFileString("/var/vcap/micro_bosh/data/cache/105d33ae-655c-493d-bf9f-1df5cf3ca847")
			Expect(err).ToNot(HaveOccurred())
			Expect(contents).To(Equal("new data"))
		})
	})
}
