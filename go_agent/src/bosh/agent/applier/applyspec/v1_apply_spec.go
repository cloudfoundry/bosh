package applyspec

import (
	"encoding/json"

	models "bosh/agent/applier/models"
)

type V1ApplySpec struct {
	PropertiesSpec    PropertiesSpec         `json:"properties"`
	JobSpec           JobSpec                `json:"job"`
	PackageSpecs      map[string]PackageSpec `json:"packages"`
	ConfigurationHash string                 `json:"configuration_hash"`
	NetworkSpecs      map[string]NetworkSpec `json:"networks"`
	ResourcePoolSpecs interface{}            `json:"resource_pool"`
	Deployment        string                 `json:"deployment"`

	// Since default value of int is 0 use pointer
	// to indicate that state does not have an assigned index
	// (json.Marshal will result in null instead of 0).
	Index *int `json:"index"`

	PersistentDisk int `json:"persistent_disk"`

	RenderedTemplatesArchiveSpec RenderedTemplatesArchiveSpec `json:"rendered_templates_archive"`
}

type PropertiesSpec struct {
	LoggingSpec LoggingSpec `json:"logging"`
}

type LoggingSpec struct {
	MaxLogFileSize string `json:"max_log_file_size"`
}

const (
	NetworkSpecTypeDynamic = "dynamic"
)

type NetworkSpec struct {
	// Instead of explicitly specifying all network fields,
	// keep original hash that Director sent because
	// Director will later fetch current apply spec via get_state
	// and use absolute equality to determine network changes.
	//
	// Ideally we would explicitly call out fields (like in 40276d6 commit)
	// and Director would check for equivalence instead of absolute hash equality.
	Fields map[string]interface{}
}

// Jobs returns a list of pre-rendered job templates
// extracted from a single tarball provided by BOSH director.
func (s V1ApplySpec) Jobs() []models.Job {
	jobsWithSource := []models.Job{}
	for _, j := range s.JobSpec.JobTemplateSpecsAsJobs() {
		j.Source = s.RenderedTemplatesArchiveSpec.AsSource(j)
		j.Packages = s.Packages()
		jobsWithSource = append(jobsWithSource, j)
	}
	return jobsWithSource
}

func (s V1ApplySpec) Packages() []models.Package {
	packages := []models.Package{}
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

func (s NetworkSpec) IsDynamic() bool {
	return s.Fields["type"] == NetworkSpecTypeDynamic
}

func (s NetworkSpec) PopulateIPInfo(ip, netmask, gateway string) NetworkSpec {
	if s.Fields == nil {
		s.Fields = map[string]interface{}{}
	}
	s.Fields["ip"] = ip
	s.Fields["netmask"] = netmask
	s.Fields["gateway"] = gateway
	return s
}

func (s *NetworkSpec) UnmarshalJSON(data []byte) error {
	return json.Unmarshal(data, &s.Fields)
}

func (s NetworkSpec) MarshalJSON() ([]byte, error) {
	return json.Marshal(s.Fields)
}
