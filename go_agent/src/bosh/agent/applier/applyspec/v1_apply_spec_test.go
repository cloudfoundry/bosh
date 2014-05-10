package applyspec_test

import (
	"encoding/json"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/applier/applyspec"
	models "bosh/agent/applier/models"
)

var _ = Describe("V1ApplySpec", func() {
	Describe("json unmarshalling", func() {
		It("returns parsed apply spec from json", func() {
			specJSON := `{
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

			spec := V1ApplySpec{}
			err := json.Unmarshal([]byte(specJSON), &spec)
			Expect(err).ToNot(HaveOccurred())

			jobName := "router"

			expectedNetworks := map[string]NetworkSpec{
				"manual-net": NetworkSpec{
					Fields: map[string]interface{}{
						"cloud_properties": map[string]interface{}{"subnet": "subnet-xxxxxx"},
						"default":          []interface{}{"dns", "gateway"},
						"dns":              []interface{}{"xx.xx.xx.xx"},
						"dns_record_name":  "job-index.job-name.manual-net.deployment-name.bosh",
						"gateway":          "xx.xx.xx.xx",
						"ip":               "xx.xx.xx.xx",
						"netmask":          "xx.xx.xx.xx",
					},
				},
				"vip-net": NetworkSpec{
					Fields: map[string]interface{}{
						"cloud_properties": map[string]interface{}{"security_groups": []interface{}{"bosh"}},
						"dns_record_name":  "job-index.job-name.vip-net.deployment-name.bosh",
						"ip":               "xx.xx.xx.xx",
						"type":             "vip",
					},
				},
			}

			expectedSpec := V1ApplySpec{
				PropertiesSpec: PropertiesSpec{
					LoggingSpec: LoggingSpec{MaxLogFileSize: "10M"},
				},
				JobSpec: JobSpec{
					Name:        &jobName,
					Template:    "router template",
					Version:     "1.0",
					Sha1:        "router sha1",
					BlobstoreID: "router-blob-id-1",
					JobTemplateSpecs: []JobTemplateSpec{
						JobTemplateSpec{Name: "template 1", Version: "0.1", Sha1: "template 1 sha1", BlobstoreID: "template-blob-id-1"},
						JobTemplateSpec{Name: "template 2", Version: "0.2", Sha1: "template 2 sha1", BlobstoreID: "template-blob-id-2"},
					},
				},
				PackageSpecs: map[string]PackageSpec{
					"package 1": PackageSpec{Name: "package 1", Version: "0.1", Sha1: "package 1 sha1", BlobstoreID: "package-blob-id-1"},
					"package 2": PackageSpec{Name: "package 2", Version: "0.2", Sha1: "package 2 sha1", BlobstoreID: "package-blob-id-2"},
				},
				RenderedTemplatesArchiveSpec: RenderedTemplatesArchiveSpec{
					Sha1:        "archive sha 1",
					BlobstoreID: "archive-blob-id-1",
				},
				NetworkSpecs: expectedNetworks,
			}

			Expect(spec).To(Equal(expectedSpec))
		})
	})

	Describe("Jobs", func() {
		It("returns jobs specified in job specs", func() {
			jobName := "fake-job-legacy-name"

			spec := V1ApplySpec{
				JobSpec: JobSpec{
					Name:        &jobName,
					Version:     "fake-job-legacy-version",
					Sha1:        "fake-job-legacy-sha1",
					BlobstoreID: "fake-job-legacy-blobstore-id",
					JobTemplateSpecs: []JobTemplateSpec{
						JobTemplateSpec{
							Name:        "fake-job1-name",
							Version:     "fake-job1-version",
							Sha1:        "fake-job1-sha1",
							BlobstoreID: "fake-job1-blobstore-id",
						},
						JobTemplateSpec{
							Name:        "fake-job2-name",
							Version:     "fake-job2-version",
							Sha1:        "fake-job2-sha1",
							BlobstoreID: "fake-job2-blobstore-id",
						},
					},
				},
				PackageSpecs: map[string]PackageSpec{
					"fake-package1": PackageSpec{
						Name:        "fake-package1-name",
						Version:     "fake-package1-version",
						Sha1:        "fake-package1-sha1",
						BlobstoreID: "fake-package1-blob-id",
					},
					"fake-package2": PackageSpec{
						Name:        "fake-package2-name",
						Version:     "fake-package2-version",
						Sha1:        "fake-package2-sha1",
						BlobstoreID: "fake-package2-blob-id",
					},
				},
				RenderedTemplatesArchiveSpec: RenderedTemplatesArchiveSpec{
					Sha1:        "fake-rendered-templates-archive-sha1",
					BlobstoreID: "fake-rendered-templates-archive-blobstore-id",
				},
			}

			expectedPackagesOnEachJob := []models.Package{
				models.Package{
					Name:    "fake-package1-name",
					Version: "fake-package1-version",
					Source: models.Source{
						Sha1:          "fake-package1-sha1",
						BlobstoreID:   "fake-package1-blob-id",
						PathInArchive: "",
					},
				},
				models.Package{
					Name:    "fake-package2-name",
					Version: "fake-package2-version",
					Source: models.Source{
						Sha1:          "fake-package2-sha1",
						BlobstoreID:   "fake-package2-blob-id",
						PathInArchive: "",
					},
				},
			}

			Expect(spec.Jobs()).To(Equal([]models.Job{
				models.Job{
					Name:    "fake-job1-name",
					Version: "fake-job1-version",
					Source: models.Source{
						Sha1:          "fake-rendered-templates-archive-sha1",
						BlobstoreID:   "fake-rendered-templates-archive-blobstore-id",
						PathInArchive: "fake-job1-name",
					},
					Packages: expectedPackagesOnEachJob,
				},
				models.Job{
					Name:    "fake-job2-name",
					Version: "fake-job2-version",
					Source: models.Source{
						Sha1:          "fake-rendered-templates-archive-sha1",
						BlobstoreID:   "fake-rendered-templates-archive-blobstore-id",
						PathInArchive: "fake-job2-name",
					},
					Packages: expectedPackagesOnEachJob,
				},
			}))
		})

		It("returns no jobs when no jobs specified", func() {
			spec := V1ApplySpec{}
			Expect(spec.Jobs()).To(Equal([]models.Job{}))
		})
	})

	Describe("Packages", func() {
		It("retuns packages", func() {
			spec := V1ApplySpec{
				PackageSpecs: map[string]PackageSpec{
					"fake-package1-name-key": PackageSpec{
						Name:        "fake-package1-name",
						Version:     "fake-package1-version",
						Sha1:        "fake-package1-sha1",
						BlobstoreID: "fake-package1-blobstore-id",
					},
				},
			}

			Expect(spec.Packages()).To(Equal([]models.Package{
				models.Package{
					Name:    "fake-package1-name",
					Version: "fake-package1-version",
					Source: models.Source{
						Sha1:        "fake-package1-sha1",
						BlobstoreID: "fake-package1-blobstore-id",
					},
				},
			}))
		})

		It("returns no packages when no packages specified", func() {
			spec := V1ApplySpec{}
			Expect(spec.Packages()).To(Equal([]models.Package{}))
		})
	})

	Describe("MaxLogFileSize", func() {
		It("returns 50M if size is not provided", func() {
			spec := V1ApplySpec{}
			Expect(spec.MaxLogFileSize()).To(Equal("50M"))
		})

		It("returns provided size", func() {
			spec := V1ApplySpec{}
			spec.PropertiesSpec.LoggingSpec.MaxLogFileSize = "fake-size"
			Expect(spec.MaxLogFileSize()).To(Equal("fake-size"))
		})
	})
})

var _ = Describe("NetworkSpec", func() {
	Describe("IsDynamic", func() {
		It("returns true if type is 'dynamic'", func() {
			networkSpec := NetworkSpec{
				Fields: map[string]interface{}{"type": NetworkSpecTypeDynamic},
			}
			Expect(networkSpec.IsDynamic()).To(BeTrue())
		})

		It("returns false if type is not 'dynamic'", func() {
			Expect(NetworkSpec{}.IsDynamic()).To(BeFalse())

			networkSpec := NetworkSpec{
				Fields: map[string]interface{}{"type": "vip"},
			}
			Expect(networkSpec.IsDynamic()).To(BeFalse())
		})
	})

	Describe("PopulateIPInfo", func() {
		It("populates network spec with ip, netmask and gateway addressess", func() {
			networkSpec := NetworkSpec{}

			networkSpec = networkSpec.PopulateIPInfo("fake-ip", "fake-netmask", "fake-gateway")

			Expect(networkSpec).To(Equal(NetworkSpec{
				Fields: map[string]interface{}{
					"ip":      "fake-ip",
					"netmask": "fake-netmask",
					"gateway": "fake-gateway",
				},
			}))
		})

		It("overwrites network spec with ip, netmask and gateway addressess", func() {
			networkSpec := NetworkSpec{
				Fields: map[string]interface{}{
					"ip":      "fake-old-ip",
					"netmask": "fake-old-netmask",
					"gateway": "fake-old-gateway",
				},
			}

			networkSpec = networkSpec.PopulateIPInfo("fake-ip", "fake-netmask", "fake-gateway")

			Expect(networkSpec).To(Equal(NetworkSpec{
				Fields: map[string]interface{}{
					"ip":      "fake-ip",
					"netmask": "fake-netmask",
					"gateway": "fake-gateway",
				},
			}))
		})
	})
})
