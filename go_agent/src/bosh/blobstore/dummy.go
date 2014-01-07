package blobstore

type dummy struct{}

func newDummyBlobstore() (blobstore dummy) {
	return
}

func (blobstore dummy) Get(blobId, fingerprint string) (fileName string, err error) {
	return
}

func (blobstore dummy) CleanUp(fileName string) (err error) {
	return
}

func (blobstore dummy) Create(fileName string) (blobId string, fingerprint string, err error) {
	return
}

func (blobstore dummy) Validate() (err error) {
	return
}
