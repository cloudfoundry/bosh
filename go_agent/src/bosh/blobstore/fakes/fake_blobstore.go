package fakes

type FakeBlobstore struct {
	GetBlobIds      []string
	GetFingerprints []string
	GetFileName     string
	GetError        error

	CleanUpFileName string
	CleanUpErr      error

	CreateFileName    string
	CreateBlobId      string
	CreateFingerprint string
	CreateErr         error

	ValidateError error
}

func NewFakeBlobstore() *FakeBlobstore {
	return &FakeBlobstore{}
}

func (bs *FakeBlobstore) Get(blobId, fingerprint string) (fileName string, err error) {
	bs.GetBlobIds = append(bs.GetBlobIds, blobId)
	bs.GetFingerprints = append(bs.GetFingerprints, fingerprint)
	fileName = bs.GetFileName
	err = bs.GetError
	return
}

func (bs *FakeBlobstore) CleanUp(fileName string) (err error) {
	bs.CleanUpFileName = fileName
	err = bs.CleanUpErr
	return
}

func (bs *FakeBlobstore) Create(fileName string) (blobId string, fingerprint string, err error) {
	bs.CreateFileName = fileName

	blobId = bs.CreateBlobId
	fingerprint = bs.CreateFingerprint
	err = bs.CreateErr
	return
}

func (bs *FakeBlobstore) Validate() (err error) {
	return bs.ValidateError
}
