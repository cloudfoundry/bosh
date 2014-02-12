package uuid_test

import (
	. "bosh/uuid"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
	"regexp"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("generate", func() {

			generator := NewGenerator()

			uuid, err := generator.Generate()
			assert.NoError(GinkgoT(), err)

			uuidFormat := "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
			uuidRegexp, _ := regexp.Compile(uuidFormat)
			assert.True(GinkgoT(), uuidRegexp.MatchString(uuid))
		})
	})
}
