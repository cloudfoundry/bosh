package applyspec_test

import (
	. "bosh/agent/applier/applyspec"
	boshassert "bosh/assert"
	fakesys "bosh/system/fakes"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildV1Service() (fs *fakesys.FakeFileSystem, specPath string, service V1Service) {
	fs = fakesys.NewFakeFileSystem()
	specPath = "/spec.json"
	service = NewConcreteV1Service(fs, specPath)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("get", func() {
			fs, specPath, service := buildV1Service()
			fs.WriteToFile(specPath, `{"deployment":"fake-deployment-name"}`)

			spec, err := service.Get()
			assert.NoError(GinkgoT(), err)
			expectedSpec := V1ApplySpec{
				Deployment: "fake-deployment-name",
			}
			assert.Equal(GinkgoT(), expectedSpec, spec)
		})
		It("set", func() {

			fs, specPath, service := buildV1Service()

			spec := V1ApplySpec{
				JobSpec: JobSpec{
					Name: "fake-job",
				},
			}

			err := service.Set(spec)
			assert.NoError(GinkgoT(), err)
			specPathStats := fs.GetFileTestStat(specPath)
			assert.NotNil(GinkgoT(), specPathStats)
			boshassert.MatchesJsonString(GinkgoT(), spec, specPathStats.Content)
		})
	})
}
