package applyspec

import "bosh/agent/applier/models"

type RenderedTemplatesArchiveSpec struct {
	Sha1        string `json:"sha1"`
	BlobstoreId string `json:"blobstore_id"`
}

func (s RenderedTemplatesArchiveSpec) AsSource(job models.Job) models.Source {
	return models.Source{
		Sha1:          s.Sha1,
		BlobstoreId:   s.BlobstoreId,
		PathInArchive: job.Name,
	}
}
