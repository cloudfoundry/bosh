package fakes

type FakeBlobstore struct {
	GetBlobIDs      []string
	GetFingerprints []string
	GetFileName     string
	GetError        error

	CleanUpFileName string
	CleanUpErr      error

	CreateFileName    string
	CreateBlobID      string
	CreateFingerprint string
	CreateErr         error

	ValidateError error
}

func NewFakeBlobstore() *FakeBlobstore {
	return &FakeBlobstore{}
}

func (bs *FakeBlobstore) Get(blobID, fingerprint string) (fileName string, err error) {
	bs.GetBlobIDs = append(bs.GetBlobIDs, blobID)
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

func (bs *FakeBlobstore) Create(fileName string) (blobID string, fingerprint string, err error) {
	bs.CreateFileName = fileName

	blobID = bs.CreateBlobID
	fingerprint = bs.CreateFingerprint
	err = bs.CreateErr
	return
}

func (bs *FakeBlobstore) Validate() (err error) {
	return bs.ValidateError
}
