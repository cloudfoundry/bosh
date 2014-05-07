package applyspec

import (
	models "bosh/agent/applier/models"
)

// V1ApplySpec should lowercase all JSON keys
// because apply spec is returned to Director via get_state action
type V1ApplySpec struct {
	ConfigurationHash string `json:"configuration_hash"`

	PropertiesSpec PropertiesSpec `json:"properties"`

	JobSpec      JobSpec                `json:"job"`
	PackageSpecs map[string]PackageSpec `json:"packages"`

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

type NetworkSpec struct {
	Type string `json:"type"`

	CloudProperties map[string]interface{} `json:"cloud_properties,omitempty"`

	// e.g. ["dns", "gateway"]
	Default []string `json:"default,omitempty"`

	// e.g. ["10.80.130.1","172.16.79.16"]
	DNS []string `json:"dns,omitempty"`

	DNSRecordName string `json:"dns_record_name"`

	Gateway string `json:"gateway"`
	IP      string `json:"ip"`
	Netmask string `json:"netmask"`

	// e.g. "00:50:56:ba:46:f0"
	MAC string `json:"mac"`
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
