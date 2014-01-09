package commands

type Compressor interface {
	CompressFilesInDir(dir string) (fileName string, err error)
	DecompressFileToDir(fileName string, dir string) (err error)
}
