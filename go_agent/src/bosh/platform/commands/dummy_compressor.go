package commands

import "os"

type DummyCompressor struct {
}

func (c DummyCompressor) CompressFilesInDir(dir string, filters []string) (file *os.File, err error) {
	return
}

func (c DummyCompressor) DecompressFileToDir(file *os.File, dir string) (err error) {
	return
}
