package blobstore

import "os"

type Blobstore interface {
	ApplyOptions(opts map[string]string) (updated Blobstore, err error)
	Create(file *os.File) (blobId string, err error)
}
