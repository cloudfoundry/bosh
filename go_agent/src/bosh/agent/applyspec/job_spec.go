package applyspec

type JobSpec struct {
	Name             string            `json:"name"`
	Version          string            `json:"version"`
	Sha1             string            `json:"sha1"`
	BlobstoreId      string            `json:"blobstore_id"`
	JobTemplateSpecs []JobTemplateSpec `json:"templates"`
}

func (s *JobSpec) AsJob() Job {
	return Job{
		Name:        s.Name,
		Version:     s.Version,
		Sha1:        s.Sha1,
		BlobstoreId: s.BlobstoreId,
	}
}

func (s *JobSpec) JobTemplateSpecsAsJobs() []Job {
	jobs := make([]Job, 0)
	for _, value := range s.JobTemplateSpecs {
		jobs = append(jobs, value.AsJob())
	}
	return jobs
}

func (s *JobSpec) IsEmpty() bool {
	return len(s.Name) == 0
}
