package applyspec

import models "bosh/agent/applier/models"

type JobSpec struct {
	Name             string            `json:"name"`
	Template         string            `json:"template"`
	Version          string            `json:"version"`
	Sha1             string            `json:"sha1"`
	BlobstoreId      string            `json:"blobstore_id"`
	JobTemplateSpecs []JobTemplateSpec `json:"templates"`
}

func (s *JobSpec) AsJob() models.Job {
	return models.Job{
		Name:    s.Template,
		Version: s.Version,
		Source: models.Source{
			Sha1:        s.Sha1,
			BlobstoreId: s.BlobstoreId,
		},
	}
}

func (s *JobSpec) JobTemplateSpecsAsJobs() []models.Job {
	jobs := make([]models.Job, 0)
	for _, value := range s.JobTemplateSpecs {
		jobs = append(jobs, value.AsJob())
	}
	return jobs
}

func (s *JobSpec) IsEmpty() bool {
	return len(s.Template) == 0
}
