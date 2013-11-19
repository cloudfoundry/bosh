package blobstore

import "os"

type Blobstore interface {
	SetOptions(opts map[string]string) (err error)
	Create(file *os.File) (blobId string, err error)
}
