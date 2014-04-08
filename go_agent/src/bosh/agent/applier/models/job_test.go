package models_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/applier/models"
)

var _ = Describe("Job", func() {
	Describe("BundleName", func() {
		It("returns name", func() {
			job := Job{Name: "fake-name"}
			Expect(job.BundleName()).To(Equal("fake-name"))
		})
	})

	Describe("BundleVersion", func() {
		It("returns version plus sha1 of source to make jobs unique", func() {
			job := Job{
				Version: "fake-version",
				Source:  Source{Sha1: "fake-sha1"},
			}
			Expect(job.BundleVersion()).To(Equal("fake-version-fake-sha1"))
		})
	})
})
