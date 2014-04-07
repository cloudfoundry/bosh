package blobstore

type dummy struct{}

func newDummyBlobstore() (blobstore dummy) {
	return
}

func (blobstore dummy) Get(blobID, fingerprint string) (fileName string, err error) {
	return
}

func (blobstore dummy) CleanUp(fileName string) (err error) {
	return
}

func (blobstore dummy) Create(fileName string) (blobID string, fingerprint string, err error) {
	return
}

func (blobstore dummy) Validate() (err error) {
	return
}
