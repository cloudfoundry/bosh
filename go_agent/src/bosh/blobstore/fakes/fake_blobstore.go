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
	CreateCallBack    func()

	ValidateError error
}

func NewFakeBlobstore() *FakeBlobstore {
	return &FakeBlobstore{}
}

func (bs *FakeBlobstore) Get(blobID, fingerprint string) (string, error) {
	bs.GetBlobIDs = append(bs.GetBlobIDs, blobID)
	bs.GetFingerprints = append(bs.GetFingerprints, fingerprint)
	return bs.GetFileName, bs.GetError
}

func (bs *FakeBlobstore) CleanUp(fileName string) error {
	bs.CleanUpFileName = fileName
	return bs.CleanUpErr
}

func (bs *FakeBlobstore) Create(fileName string) (string, string, error) {
	bs.CreateFileName = fileName

	if bs.CreateCallBack != nil {
		bs.CreateCallBack()
	}

	return bs.CreateBlobID, bs.CreateFingerprint, bs.CreateErr
}

func (bs *FakeBlobstore) Validate() error {
	return bs.ValidateError
}
