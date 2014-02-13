package fakes

type FakeCdUtil struct {
	GetFileContentsFilename string
	GetFileContentsError    error
	GetFileContentsContents []byte
}

func NewFakeCdUtil() (util *FakeCdUtil) {
	util = &FakeCdUtil{}
	return
}

func (util *FakeCdUtil) GetFileContents(fileName string) (contents []byte, err error) {
	util.GetFileContentsFilename = fileName
	contents = util.GetFileContentsContents
	err = util.GetFileContentsError
	return
}
