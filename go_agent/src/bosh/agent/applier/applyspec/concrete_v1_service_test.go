package applyspec_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/applier/applyspec"
	boshassert "bosh/assert"
	fakesys "bosh/system/fakes"
)

func init() {
	Describe("concreteV1Service", func() {
		var (
			fs       *fakesys.FakeFileSystem
			specPath string
			service  V1Service
		)

		BeforeEach(func() {
			fs = fakesys.NewFakeFileSystem()
			specPath = "/spec.json"
			service = NewConcreteV1Service(fs, specPath)
		})

		Describe("Get", func() {
			Context("when filesystem has a spec file", func() {
				BeforeEach(func() {
					fs.WriteFileString(specPath, `{"deployment":"fake-deployment-name"}`)
				})

				It("reads spec from filesystem", func() {
					spec, err := service.Get()
					Expect(err).ToNot(HaveOccurred())
					Expect(spec).To(Equal(V1ApplySpec{Deployment: "fake-deployment-name"}))
				})

				It("returns error if reading spec from filesystem errs", func() {
					fs.ReadFileError = errors.New("fake-read-error")

					spec, err := service.Get()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-read-error"))
					Expect(spec).To(Equal(V1ApplySpec{}))
				})
			})

			Context("when filesystem does not have a spec file", func() {
				It("reads spec from filesystem", func() {
					spec, err := service.Get()
					Expect(err).ToNot(HaveOccurred())
					Expect(spec).To(Equal(V1ApplySpec{}))
				})
			})
		})

		Describe("Set", func() {
			newSpec := V1ApplySpec{
				JobSpec: JobSpec{Name: "fake-job"},
			}

			It("writes spec to filesystem", func() {
				err := service.Set(newSpec)
				Expect(err).ToNot(HaveOccurred())

				specPathStats := fs.GetFileTestStat(specPath)
				Expect(specPathStats).ToNot(BeNil())
				boshassert.MatchesJsonBytes(GinkgoT(), newSpec, specPathStats.Content)
			})

			It("returns error if writing spec to filesystem errs", func() {
				fs.WriteToFileError = errors.New("fake-write-error")

				err := service.Set(newSpec)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-write-error"))
			})
		})

	})
}
