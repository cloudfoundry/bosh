package disk

import "os"

type Compressor interface {
	CompressFilesInDir(dir string, filters []string) (tarball *os.File, err error)
}
