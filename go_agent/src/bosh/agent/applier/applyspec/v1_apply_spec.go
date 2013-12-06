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

	RenderedTemplatesArchiveSpec []RenderedTemplatesArchiveSpec `json:"rendered_templates_archive"`
}

type PropertiesSpec struct {
	LoggingSpec LoggingSpec `json:"logging"`
}

type LoggingSpec struct {
	MaxLogFileSize string `json:"max_log_file_size"`
}

type RenderedTemplatesArchiveSpec struct {
	Sha1        string `json:"sha1"`
	BlobstoreId string `json:"blobstore_id"`
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

func (s V1ApplySpec) Jobs() []models.Job {
	if len(s.JobSpec.JobTemplateSpecs) > 0 {
		return s.JobSpec.JobTemplateSpecsAsJobs()
	}
	if s.JobSpec.IsEmpty() {
		return []models.Job{}
	}
	return []models.Job{s.JobSpec.AsJob()}
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
