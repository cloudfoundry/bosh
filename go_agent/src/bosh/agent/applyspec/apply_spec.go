package applyspec

import (
	bosherr "bosh/errors"
	"encoding/json"
)

type ApplySpec struct {
	PropertiesSpec PropertiesSpec `json:"properties"`
	JobSpec        JobSpec        `json:"job"`
	PackageSpecs   []PackageSpec  `json:"packages"`
}

// Currently uses json.Unmarshal to interpret data into structs.
// Will be replaced with generic unmarshaler that operates on maps.
func NewApplySpecFromData(data interface{}) (as *ApplySpec, err error) {
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

func NewApplySpecFromJson(dataAsJson []byte) (as *ApplySpec, err error) {
	err = json.Unmarshal(dataAsJson, &as)
	if err != nil {
		err = bosherr.WrapError(err, "Failed to interpret apply spec")
		return
	}

	return
}

func (s *ApplySpec) MaxLogFileSize() string {
	fileSize := s.PropertiesSpec.LoggingSpec.MaxLogFileSize
	if len(fileSize) > 0 {
		return fileSize
	}
	return "50M"
}

func (s *ApplySpec) Jobs() []Job {
	if len(s.JobSpec.JobTemplateSpecs) > 0 {
		return s.JobSpec.JobTemplateSpecsAsJobs()
	}
	return []Job{s.JobSpec.AsJob()}
}

func (s *ApplySpec) Packages() []Package {
	packages := make([]Package, 0)
	for _, value := range s.PackageSpecs {
		packages = append(packages, value.AsPackage())
	}
	return packages
}

type PropertiesSpec struct {
	LoggingSpec LoggingSpec `json:"logging"`
}

type LoggingSpec struct {
	MaxLogFileSize string `json:"max_log_file_size"`
}
