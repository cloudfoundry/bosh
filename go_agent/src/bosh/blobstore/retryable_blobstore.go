package blobstore

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
)

const retryableBlobstoreLogTag = "retryableBlobstore"

type retryableBlobstore struct {
	blobstore Blobstore
	maxTries  int
	logger    boshlog.Logger
}

func NewRetryableBlobstore(blobstore Blobstore, maxTries int, logger boshlog.Logger) Blobstore {
	return retryableBlobstore{
		blobstore: blobstore,
		maxTries:  maxTries,
		logger:    logger,
	}
}

func (b retryableBlobstore) Get(blobID, fingerprint string) (string, error) {
	var fileName string
	var lastErr error

	for i := 0; i < b.maxTries; i++ {
		fileName, lastErr = b.blobstore.Get(blobID, fingerprint)
		if lastErr == nil {
			return fileName, nil
		}

		b.logger.Info(retryableBlobstoreLogTag,
			"Failed to get blob with error %s, attempt %d", lastErr.Error(), i)
	}

	return "", bosherr.WrapError(lastErr, "Getting blob from inner blobstore")
}

func (b retryableBlobstore) CleanUp(fileName string) error {
	return b.blobstore.CleanUp(fileName)
}

func (b retryableBlobstore) Create(fileName string) (string, string, error) {
	return b.blobstore.Create(fileName)
}

func (b retryableBlobstore) Validate() error {
	if b.maxTries < 1 {
		return bosherr.New("Max tries must be > 0")
	}

	return b.blobstore.Validate()
}
