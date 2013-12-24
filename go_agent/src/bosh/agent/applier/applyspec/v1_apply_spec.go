package applyspec

import (
	models "bosh/agent/applier/models"
)

type V1ApplySpec struct {
	PropertiesSpec    PropertiesSpec         `json:"properties"`
	JobSpec           JobSpec                `json:"job"`
	PackageSpecs      map[string]PackageSpec `json:"packages"`
	ConfigurationHash string                 `json:"configuration_hash"`
	NetworkSpecs      map[string]interface{} `json:"networks"`
	ResourcePoolSpecs interface{}            `json:"resource_pool"`
	Deployment        string                 `json:"deployment"`
	Index             int                    `json:"index"`
	PersistentDisk    int                    `json:"persistent_disk"`

	RenderedTemplatesArchiveSpec RenderedTemplatesArchiveSpec `json:"rendered_templates_archive"`
}

type PropertiesSpec struct {
	LoggingSpec LoggingSpec `json:"logging"`
}

type LoggingSpec struct {
	MaxLogFileSize string `json:"max_log_file_size"`
}

// BOSH Director provides a single tarball with all job templates pre-rendered
func (s V1ApplySpec) Jobs() []models.Job {
	jobsWithSource := []models.Job{}
	for _, j := range s.JobSpec.JobTemplateSpecsAsJobs() {
		j.Source = s.RenderedTemplatesArchiveSpec.AsSource(j)
		jobsWithSource = append(jobsWithSource, j)
	}
	return jobsWithSource
}

func (s V1ApplySpec) Packages() []models.Package {
	packages := make([]models.Package, 0)
	for _, value := range s.PackageSpecs {
		packages = append(packages, value.AsPackage())
	}
	return packages
}

func (s V1ApplySpec) MaxLogFileSize() string {
	fileSize := s.PropertiesSpec.LoggingSpec.MaxLogFileSize
	if len(fileSize) > 0 {
		return fileSize
	}
	return "50M"
}
