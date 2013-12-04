package applyspec

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestMaxLogFileSize(t *testing.T) {
	// No 'properties'
	spec, err := NewApplySpecFromData(
		map[string]interface{}{},
	)
	assert.NoError(t, err)
	assert.Equal(t, "50M", spec.MaxLogFileSize())

	// No 'logging' in properties
	spec, err = NewApplySpecFromData(
		map[string]interface{}{
			"properties": map[string]interface{}{},
		},
	)
	assert.NoError(t, err)
	assert.Equal(t, "50M", spec.MaxLogFileSize())

	// No 'max_log_file_size' in logging
	spec, err = NewApplySpecFromData(
		map[string]interface{}{
			"properties": map[string]interface{}{
				"logging": map[string]interface{}{},
			},
		},
	)
	assert.NoError(t, err)
	assert.Equal(t, "50M", spec.MaxLogFileSize())

	// Specified 'max_log_file_size'
	spec, err = NewApplySpecFromData(
		map[string]interface{}{
			"properties": map[string]interface{}{
				"logging": map[string]interface{}{
					"max_log_file_size": "fake-size",
				},
			},
		},
	)
	assert.NoError(t, err)
	assert.Equal(t, "fake-size", spec.MaxLogFileSize())
}

func TestJobsWithSpecifiedJobTemplates(t *testing.T) {
	spec, err := NewApplySpecFromData(
		map[string]interface{}{
			"job": map[string]interface{}{
				"name":         "fake-job-legacy-name",
				"version":      "fake-job-legacy-version",
				"sha1":         "fake-job-legacy-sha1",
				"blobstore_id": "fake-job-legacy-blobstore-id",
				"templates": []interface{}{
					map[string]interface{}{
						"name":         "fake-job1-name",
						"version":      "fake-job1-version",
						"sha1":         "fake-job1-sha1",
						"blobstore_id": "fake-job1-blobstore-id",
					},
				},
				"release":  "fake-job-release",
				"template": "fake-job-template",
			},
		},
	)
	assert.NoError(t, err)
	assert.Equal(t, []Job{
		Job{
			Name:        "fake-job1-name",
			Version:     "fake-job1-version",
			Sha1:        "fake-job1-sha1",
			BlobstoreId: "fake-job1-blobstore-id",
		},
	}, spec.Jobs())
}

func TestJobsWithoutSpecifiedJobTemplates(t *testing.T) {
	spec, err := NewApplySpecFromData(
		map[string]interface{}{
			"job": map[string]interface{}{
				"name":         "fake-job-legacy-name",
				"version":      "fake-job-legacy-version",
				"sha1":         "fake-job-legacy-sha1",
				"blobstore_id": "fake-job-legacy-blobstore-id",
				"release":      "fake-job-legacy-release",
				"template":     "fake-job-legacy-template",
			},
		},
	)
	assert.NoError(t, err)
	assert.Equal(t, []Job{
		Job{
			// template is used as a job name to be backwards compatible
			Name:        "fake-job-legacy-template",
			Version:     "fake-job-legacy-version",
			Sha1:        "fake-job-legacy-sha1",
			BlobstoreId: "fake-job-legacy-blobstore-id",
		},
	}, spec.Jobs())
}

func TestJobsWhenNoJobsSpecified(t *testing.T) {
	spec, err := NewApplySpecFromData(map[string]interface{}{})
	assert.NoError(t, err)
	assert.Equal(t, []Job{}, spec.Jobs())
}

func TestPackages(t *testing.T) {
	spec, err := NewApplySpecFromData(
		map[string]interface{}{
			"packages": []interface{}{
				map[string]interface{}{
					"name":         "fake-package1-name",
					"version":      "fake-package1-version",
					"sha1":         "fake-package1-sha1",
					"blobstore_id": "fake-package1-blobstore-id",
				},
			},
		},
	)
	assert.NoError(t, err)
	assert.Equal(t, []Package{
		Package{
			Name:        "fake-package1-name",
			Version:     "fake-package1-version",
			Sha1:        "fake-package1-sha1",
			BlobstoreId: "fake-package1-blobstore-id",
		},
	}, spec.Packages())
}

func TestPackagesWhenNoPackagesSpecified(t *testing.T) {
	spec, err := NewApplySpecFromData(map[string]interface{}{})
	assert.NoError(t, err)
	assert.Equal(t, []Package{}, spec.Packages())
}
