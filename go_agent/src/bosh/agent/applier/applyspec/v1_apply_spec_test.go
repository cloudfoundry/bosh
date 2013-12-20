package applyspec

import (
	models "bosh/agent/applier/models"
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestV1ApplySpecJsonConversion(t *testing.T) {
	specJson := `{
		"properties": {
			"logging": {"max_log_file_size": "10M"}
		},
		"job": {
			"name": "router",
			"template": "router template",
			"version": "1.0",
			"sha1": "router sha1",
			"blobstore_id": "router-blob-id-1",
			"templates": [
				{"name": "template 1", "version": "0.1", "sha1": "template 1 sha1", "blobstore_id": "template-blob-id-1"},
				{"name": "template 2", "version": "0.2", "sha1": "template 2 sha1", "blobstore_id": "template-blob-id-2"}
			]
		},
		"packages": {
			"package 1": {"name": "package 1", "version": "0.1", "sha1": "package 1 sha1", "blobstore_id": "package-blob-id-1"},
			"package 2": {"name": "package 2", "version": "0.2", "sha1": "package 2 sha1", "blobstore_id": "package-blob-id-2"}
		},
		"networks": {
			"manual-net": {
				"cloud_properties": {
					"subnet": "subnet-xxxxxx"
				},
				"default": [
					"dns",
					"gateway"
				],
				"dns": [
					"xx.xx.xx.xx"
				],
				"dns_record_name": "job-index.job-name.manual-net.deployment-name.bosh",
				"gateway": "xx.xx.xx.xx",
				"ip": "xx.xx.xx.xx",
				"netmask": "xx.xx.xx.xx"
			},
			"vip-net": {
				"cloud_properties": {
					"security_groups": [
						"bosh"
					]
				},
				"dns_record_name": "job-index.job-name.vip-net.deployment-name.bosh",
				"ip": "xx.xx.xx.xx",
				"type": "vip"
			}
		},
		"rendered_templates_archive": {
			"sha1": "archive sha 1",
			"blobstore_id": "archive-blob-id-1"
		}
	}`

	expectedNetworks := map[string]interface{}{
		"manual-net": map[string]interface{}{
			"cloud_properties": map[string]interface{}{"subnet": "subnet-xxxxxx"},
			"default":          []interface{}{"dns", "gateway"},
			"dns":              []interface{}{"xx.xx.xx.xx"},
			"dns_record_name":  "job-index.job-name.manual-net.deployment-name.bosh",
			"gateway":          "xx.xx.xx.xx",
			"ip":               "xx.xx.xx.xx",
			"netmask":          "xx.xx.xx.xx",
		},
		"vip-net": map[string]interface{}{
			"cloud_properties": map[string]interface{}{"security_groups": []interface{}{"bosh"}},
			"dns_record_name":  "job-index.job-name.vip-net.deployment-name.bosh",
			"ip":               "xx.xx.xx.xx",
			"type":             "vip",
		},
	}

	expectedSpec := V1ApplySpec{
		PropertiesSpec: PropertiesSpec{
			LoggingSpec: LoggingSpec{MaxLogFileSize: "10M"},
		},
		JobSpec: JobSpec{
			Name:        "router",
			Template:    "router template",
			Version:     "1.0",
			Sha1:        "router sha1",
			BlobstoreId: "router-blob-id-1",
			JobTemplateSpecs: []JobTemplateSpec{
				{Name: "template 1", Version: "0.1", Sha1: "template 1 sha1", BlobstoreId: "template-blob-id-1"},
				{Name: "template 2", Version: "0.2", Sha1: "template 2 sha1", BlobstoreId: "template-blob-id-2"},
			},
		},
		PackageSpecs: map[string]PackageSpec{
			"package 1": PackageSpec{Name: "package 1", Version: "0.1", Sha1: "package 1 sha1", BlobstoreId: "package-blob-id-1"},
			"package 2": PackageSpec{Name: "package 2", Version: "0.2", Sha1: "package 2 sha1", BlobstoreId: "package-blob-id-2"},
		},
		RenderedTemplatesArchiveSpec: RenderedTemplatesArchiveSpec{
			Sha1:        "archive sha 1",
			BlobstoreId: "archive-blob-id-1",
		},
		NetworkSpecs: expectedNetworks,
	}

	spec := V1ApplySpec{}
	err := json.Unmarshal([]byte(specJson), &spec)

	assert.NoError(t, err)
	assert.Equal(t, spec.NetworkSpecs, expectedNetworks)
	assert.Equal(t, spec, expectedSpec)
}

func TestJobsWithSpecifiedJobTemplates(t *testing.T) {
	spec := V1ApplySpec{
		JobSpec: JobSpec{
			Name:        "fake-job-legacy-name",
			Version:     "fake-job-legacy-version",
			Sha1:        "fake-job-legacy-sha1",
			BlobstoreId: "fake-job-legacy-blobstore-id",
			JobTemplateSpecs: []JobTemplateSpec{
				JobTemplateSpec{
					Name:        "fake-job1-name",
					Version:     "fake-job1-version",
					Sha1:        "fake-job1-sha1",
					BlobstoreId: "fake-job1-blobstore-id",
				},
				JobTemplateSpec{
					Name:        "fake-job2-name",
					Version:     "fake-job2-version",
					Sha1:        "fake-job2-sha1",
					BlobstoreId: "fake-job2-blobstore-id",
				},
			},
		},
		RenderedTemplatesArchiveSpec: RenderedTemplatesArchiveSpec{
			Sha1:        "fake-rendered-templates-archive-sha1",
			BlobstoreId: "fake-rendered-templates-archive-blobstore-id",
		},
	}
	assert.Equal(t, []models.Job{
		models.Job{
			Name:    "fake-job1-name",
			Version: "fake-job1-version",
			Source: models.Source{
				Sha1:          "fake-rendered-templates-archive-sha1",
				BlobstoreId:   "fake-rendered-templates-archive-blobstore-id",
				PathInArchive: "fake-job1-name",
			},
		},
		models.Job{
			Name:    "fake-job2-name",
			Version: "fake-job2-version",
			Source: models.Source{
				Sha1:          "fake-rendered-templates-archive-sha1",
				BlobstoreId:   "fake-rendered-templates-archive-blobstore-id",
				PathInArchive: "fake-job2-name",
			},
		},
	}, spec.Jobs())
}

func TestJobsWhenNoJobsSpecified(t *testing.T) {
	spec := V1ApplySpec{}
	assert.Equal(t, []models.Job{}, spec.Jobs())
}

func TestPackages(t *testing.T) {
	spec := V1ApplySpec{
		PackageSpecs: map[string]PackageSpec{
			"fake-package1-name-key": PackageSpec{
				Name:        "fake-package1-name",
				Version:     "fake-package1-version",
				Sha1:        "fake-package1-sha1",
				BlobstoreId: "fake-package1-blobstore-id",
			},
		},
	}

	assert.Equal(t, []models.Package{
		models.Package{
			Name:    "fake-package1-name",
			Version: "fake-package1-version",
			Source: models.Source{
				Sha1:        "fake-package1-sha1",
				BlobstoreId: "fake-package1-blobstore-id",
			},
		},
	}, spec.Packages())
}

func TestPackagesWhenNoPackagesSpecified(t *testing.T) {
	spec := V1ApplySpec{}
	assert.Equal(t, []models.Package{}, spec.Packages())
}

func TestMaxLogFileSize(t *testing.T) {
	// No 'properties'
	spec := V1ApplySpec{}
	assert.Equal(t, "50M", spec.MaxLogFileSize())

	// Specified 'max_log_file_size'
	spec.PropertiesSpec.LoggingSpec.MaxLogFileSize = "fake-size"
	assert.Equal(t, "fake-size", spec.MaxLogFileSize())
}
