package models_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/applier/models"
)

var _ = Describe("Package", func() {
	Describe("BundleName", func() {
		It("returns name", func() {
			pkg := Package{Name: "fake-name"}
			Expect(pkg.BundleName()).To(Equal("fake-name"))
		})
	})

	Describe("BundleVersion", func() {
		It("returns version plus sha1 of source to make packages unique", func() {
			pkg := Package{
				Version: "fake-version",
				Source:  Source{Sha1: "fake-sha1"},
			}
			Expect(pkg.BundleVersion()).To(Equal("fake-version-fake-sha1"))
		})
	})
})
