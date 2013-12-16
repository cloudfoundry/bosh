package blobstore

import "os"

type Blobstore interface {
	ApplyOptions(opts map[string]string) (updated Blobstore, err error)

	// Assuming that local file system is available,
	// file handle is returned to downloaded blob.
	// Caller must not assume anything about layout of such scratch space.
	// Cleanup call is needed to properly cleanup downloaded blob.
	Get(blobId string) (file *os.File, err error)

	CleanUp(file *os.File) (err error)

	Create(file *os.File) (blobId string, err error)
}
