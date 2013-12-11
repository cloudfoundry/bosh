package commands

type DummyCompressor struct {
}

func (c DummyCompressor) CompressFilesInDir(dir string, filters []string) (fileName string, err error) {
	return
}

func (c DummyCompressor) DecompressFileToDir(fileName string, dir string) (err error) {
	return
}
