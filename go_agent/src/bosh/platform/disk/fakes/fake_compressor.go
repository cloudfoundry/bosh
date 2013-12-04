package fakes

import "os"

type FakeCompressor struct {
	CompressFilesInDirTarball *os.File
	CompressFilesInDirDir     string
	CompressFilesInDirFilters []string
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
