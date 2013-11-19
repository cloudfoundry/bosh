package blobstore

import "os"

type s3 struct {
}

func newS3Blobstore() (blobstore s3) {
	return
}

// Blobstore client for S3 with optional object encryption - Options include:
//
// [required] bucket_name
// [optional] encryption_key - encryption key that gets applied before the object is sent to S3
// [optional] access_key_id
// [optional] secret_access_key
//
// If access_key_id and secret_access_key are not present, the blobstore client
// operates in read only mode as a simple_blobstore_client
func (blobstore s3) SetOptions(opts map[string]string) (err error) {
	return
}

func (blobstore s3) Create(file *os.File) (blobId string, err error) {
	return
}
