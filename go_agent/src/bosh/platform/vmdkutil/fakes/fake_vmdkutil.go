package fakes

type FakeVmdkUtil struct {
	GetFileContentsFilename string
	GetFileContentsError    error
	GetFileContentsContents []byte
}

func NewFakeVmdkUtil() (util *FakeVmdkUtil) {
	util = &FakeVmdkUtil{}
	return
}

func (util *FakeVmdkUtil) GetFileContents(fileName string) (contents []byte, err error) {
	util.GetFileContentsFilename = fileName
	contents = util.GetFileContentsContents
	err = util.GetFileContentsError
	return
}
