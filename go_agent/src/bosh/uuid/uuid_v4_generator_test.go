package uuid_test

import (
	"regexp"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/uuid"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("generate", func() {

			generator := NewGenerator()

			uuid, err := generator.Generate()
			Expect(err).ToNot(HaveOccurred())

			uuidFormat := "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
			uuidRegexp, _ := regexp.Compile(uuidFormat)
			Expect(uuidRegexp.MatchString(uuid)).To(BeTrue())
		})
	})
}
