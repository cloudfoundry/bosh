package app_test

import (
	. "bosh/app"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("parse options parses the infrastructure", func() {

			opts, err := ParseOptions([]string{"bosh-agent", "-I", "foo"})
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), opts.InfrastructureName, "foo")

			opts, err = ParseOptions([]string{"bosh-agent"})
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), opts.InfrastructureName, "")
		})
		It("parse options parses the platform", func() {

			opts, err := ParseOptions([]string{"bosh-agent", "-P", "baz"})
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), opts.PlatformName, "baz")

			opts, err = ParseOptions([]string{"bosh-agent"})
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), opts.PlatformName, "")
		})
	})
}
