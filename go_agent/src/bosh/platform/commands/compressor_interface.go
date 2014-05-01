package commands

type Compressor interface {
	// CompressFilesInDir returns path to a compressed file
	CompressFilesInDir(dir string) (path string, err error)

	DecompressFileToDir(path string, dir string) (err error)

	// CleanUp cleans up compressed file after it was used
	CleanUp(path string) error
}
