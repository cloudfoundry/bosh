package fakes

import "os"

type FakeCompressor struct{}

func NewFakeCompressor() (fc FakeCompressor) {
	return
}

func (fc FakeCompressor) CompressFilesInDir(dir string, filters []string) (tarball *os.File, err error) {
	return
}
