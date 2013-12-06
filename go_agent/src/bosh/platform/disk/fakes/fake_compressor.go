package fakes

import "os"

type FakeCompressor struct {
	CompressFilesInDirTarball *os.File
	CompressFilesInDirDir     string
	CompressFilesInDirFilters []string

	DecompressFileToDirTarball *os.File
	DecompressFileToDirDir     string
	DecompressFileToDirError   error
}

func NewFakeCompressor() *FakeCompressor {
	return &FakeCompressor{}
}

func (fc *FakeCompressor) CompressFilesInDir(dir string, filters []string) (tarball *os.File, err error) {
	fc.CompressFilesInDirDir = dir
	fc.CompressFilesInDirFilters = filters

	tarball = fc.CompressFilesInDirTarball
	return
}

func (fc *FakeCompressor) DecompressFileToDir(tarball *os.File, dir string) (err error) {
	fc.DecompressFileToDirTarball = tarball
	fc.DecompressFileToDirDir = dir

	err = fc.DecompressFileToDirError
	return
}
