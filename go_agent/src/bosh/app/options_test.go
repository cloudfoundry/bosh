package app_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/app"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("parse options parses the infrastructure", func() {

			opts, err := ParseOptions([]string{"bosh-agent", "-I", "foo"})
			Expect(err).ToNot(HaveOccurred())
			Expect(opts.InfrastructureName).To(Equal("foo"))

			opts, err = ParseOptions([]string{"bosh-agent"})
			Expect(err).ToNot(HaveOccurred())
			Expect(opts.InfrastructureName).To(Equal(""))
		})
		It("parse options parses the platform", func() {

			opts, err := ParseOptions([]string{"bosh-agent", "-P", "baz"})
			Expect(err).ToNot(HaveOccurred())
			Expect(opts.PlatformName).To(Equal("baz"))

			opts, err = ParseOptions([]string{"bosh-agent"})
			Expect(err).ToNot(HaveOccurred())
			Expect(opts.PlatformName).To(Equal(""))
		})
	})
}
