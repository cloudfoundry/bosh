package disk

import "os"

type Compressor interface {
	CompressFilesInDir(dir string, filters []string) (file *os.File, err error)
	DecompressFileToDir(file *os.File, dir string) (err error)
}
