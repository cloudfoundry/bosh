package applyspec

import (
	models "bosh/agent/applier/models"
)

type JobSpec struct {
	Name             *string           `json:"name"`
	Release          string            `json:"release"`
	Template         string            `json:"template"`
	Version          string            `json:"version"`
	Sha1             string            `json:"sha1"`
	BlobstoreID      string            `json:"blobstore_id"`
	JobTemplateSpecs []JobTemplateSpec `json:"templates"`
}

func (s *JobSpec) JobTemplateSpecsAsJobs() []models.Job {
	jobs := []models.Job{}
	for _, value := range s.JobTemplateSpecs {
		jobs = append(jobs, value.AsJob())
	}
	return jobs
}
