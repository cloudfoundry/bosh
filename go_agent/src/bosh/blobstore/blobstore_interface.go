package blobstore

type Blobstore interface {
	ApplyOptions(opts map[string]string) (updated Blobstore, err error)

	// Assuming that local file system is available,
	// file handle is returned to downloaded blob.
	// Caller must not assume anything about layout of such scratch space.
	// Cleanup call is needed to properly cleanup downloaded blob.
	Get(blobId, fingerprint string) (fileName string, err error)

	CleanUp(fileName string) (err error)

	Create(fileName string) (blobId string, fingerprint string, err error)

	Valid() bool
}
