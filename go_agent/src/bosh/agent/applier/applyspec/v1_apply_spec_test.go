package applyspec

import (
	models "bosh/agent/applier/models"
	"github.com/stretchr/testify/assert"
	"testing"
)

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
