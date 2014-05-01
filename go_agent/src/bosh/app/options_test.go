package app_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/app"
)

var _ = Describe("ParseOptions", func() {
	It("parses the infrastructure", func() {
		opts, err := ParseOptions([]string{"bosh-agent", "-I", "foo"})
		Expect(err).ToNot(HaveOccurred())
		Expect(opts.InfrastructureName).To(Equal("foo"))

		opts, err = ParseOptions([]string{"bosh-agent"})
		Expect(err).ToNot(HaveOccurred())
		Expect(opts.InfrastructureName).To(Equal(""))
	})

	It("parses the platform", func() {
		opts, err := ParseOptions([]string{"bosh-agent", "-P", "baz"})
		Expect(err).ToNot(HaveOccurred())
		Expect(opts.PlatformName).To(Equal("baz"))

		opts, err = ParseOptions([]string{"bosh-agent"})
		Expect(err).ToNot(HaveOccurred())
		Expect(opts.PlatformName).To(Equal(""))
	})

	It("parses config path", func() {
		opts, err := ParseOptions([]string{"bosh-agent", "-C", "/fake-path"})
		Expect(err).ToNot(HaveOccurred())
		Expect(opts.ConfigPath).To(Equal("/fake-path"))

		opts, err = ParseOptions([]string{"bosh-agent"})
		Expect(err).ToNot(HaveOccurred())
		Expect(opts.ConfigPath).To(Equal(""))
	})
})
