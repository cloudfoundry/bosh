package fakes

type FakeCompressor struct {
	CompressFilesInDirTarballPath string
	CompressFilesInDirDir         string
	CompressFilesInDirErr         error

	DecompressFileToDirTarballPaths []string
	DecompressFileToDirDirs         []string
	DecompressFileToDirErr          error
	DecompressFileToDirCallBack     func()
}

func NewFakeCompressor() *FakeCompressor {
	return &FakeCompressor{}
}

func (fc *FakeCompressor) CompressFilesInDir(dir string) (string, error) {
	fc.CompressFilesInDirDir = dir
	return fc.CompressFilesInDirTarballPath, fc.CompressFilesInDirErr
}

func (fc *FakeCompressor) DecompressFileToDir(tarballPath string, dir string) (err error) {
	fc.DecompressFileToDirTarballPaths = append(fc.DecompressFileToDirTarballPaths, tarballPath)
	fc.DecompressFileToDirDirs = append(fc.DecompressFileToDirDirs, dir)

	if fc.DecompressFileToDirCallBack != nil {
		fc.DecompressFileToDirCallBack()
	}

	return fc.DecompressFileToDirErr
}
