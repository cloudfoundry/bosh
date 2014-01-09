package fakes

type DecompressFileToDirCallBackFunc func()

type FakeCompressor struct {
	CompressFilesInDirTarballPath   string
	CompressFilesInDirDir           string
	DecompressFileToDirTarballPaths []string
	DecompressFileToDirDirs         []string
	DecompressFileToDirError        error
	DecompressFileToDirCallBack     DecompressFileToDirCallBackFunc
}

func NewFakeCompressor() *FakeCompressor {
	return &FakeCompressor{}
}

func (fc *FakeCompressor) CompressFilesInDir(dir string) (tarballPath string, err error) {
	fc.CompressFilesInDirDir = dir

	tarballPath = fc.CompressFilesInDirTarballPath
	return
}

func (fc *FakeCompressor) DecompressFileToDir(tarballPath string, dir string) (err error) {
	fc.DecompressFileToDirTarballPaths = append(fc.DecompressFileToDirTarballPaths, tarballPath)
	fc.DecompressFileToDirDirs = append(fc.DecompressFileToDirDirs, dir)

	if fc.DecompressFileToDirCallBack != nil {
		fc.DecompressFileToDirCallBack()
	}

	err = fc.DecompressFileToDirError
	return
}
