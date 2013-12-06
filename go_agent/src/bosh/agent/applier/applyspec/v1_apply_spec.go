package applyspec

import (
	models "bosh/agent/applier/models"
	bosherr "bosh/errors"
	"encoding/json"
)

type V1ApplySpec struct {
	PropertiesSpec PropertiesSpec `json:"properties"`
	JobSpec        JobSpec        `json:"job"`
	PackageSpecs   []PackageSpec  `json:"packages"`

	RenderedTemplatesArchiveSpec RenderedTemplatesArchiveSpec `json:"rendered_templates_archive"`
}

type PropertiesSpec struct {
	LoggingSpec LoggingSpec `json:"logging"`
}

type LoggingSpec struct {
	MaxLogFileSize string `json:"max_log_file_size"`
}

// Currently uses json.Unmarshal to interpret data into structs.
// Will be replaced with generic unmarshaler that operates on maps.
func NewV1ApplySpecFromData(data interface{}) (as V1ApplySpec, err error) {
	dataAsJson, err := json.Marshal(data)
	if err != nil {
		err = bosherr.WrapError(err, "Failed to interpret apply spec")
		return
	}

	err = json.Unmarshal(dataAsJson, &as)
	if err != nil {
		err = bosherr.WrapError(err, "Failed to interpret apply spec")
		return
	}

	return
}

func NewV1ApplySpecFromJson(dataAsJson []byte) (as V1ApplySpec, err error) {
	err = json.Unmarshal(dataAsJson, &as)
	if err != nil {
		err = bosherr.WrapError(err, "Failed to interpret apply spec")
		return
	}

	return
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
