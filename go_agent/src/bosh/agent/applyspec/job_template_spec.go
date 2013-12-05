package applyspec

type JobTemplateSpec struct {
	Name        string `json:"name"`
	Version     string `json:"version"`
	Sha1        string `json:"sha1"`
	BlobstoreId string `json:"blobstore_id"`
}

func (s *JobTemplateSpec) AsJob() Job {
	return Job{
		Name:        s.Name,
		Version:     s.Version,
		Sha1:        s.Sha1,
		BlobstoreId: s.BlobstoreId,
	}
}
