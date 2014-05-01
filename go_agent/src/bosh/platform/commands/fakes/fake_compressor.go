package fakes

type FakeCompressor struct {
	CompressFilesInDirDir         string
	CompressFilesInDirTarballPath string
	CompressFilesInDirErr         error

	DecompressFileToDirTarballPaths []string
	DecompressFileToDirDirs         []string
	DecompressFileToDirErr          error
	DecompressFileToDirCallBack     func()

	CleanUpTarballPath string
	CleanUpErr         error
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

func (fc *FakeCompressor) CleanUp(tarballPath string) error {
	fc.CleanUpTarballPath = tarballPath
	return fc.CleanUpErr
}
