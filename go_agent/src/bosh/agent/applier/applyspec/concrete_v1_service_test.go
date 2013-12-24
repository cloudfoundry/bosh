package applyspec

import (
	boshassert "bosh/assert"
	fakesys "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGet(t *testing.T) {
	fs, specPath, service := buildV1Service()
	fs.WriteToFile(specPath, `{"deployment":"fake-deployment-name"}`)

	spec, err := service.Get()
	assert.NoError(t, err)
	expectedSpec := V1ApplySpec{
		Deployment: "fake-deployment-name",
	}
	assert.Equal(t, expectedSpec, spec)
}

func TestSet(t *testing.T) {
	fs, specPath, service := buildV1Service()

	spec := V1ApplySpec{
		JobSpec: JobSpec{
			Name: "fake-job",
		},
	}

	err := service.Set(spec)
	assert.NoError(t, err)
	specPathStats := fs.GetFileTestStat(specPath)
	assert.NotNil(t, specPathStats)
	boshassert.MatchesJsonString(t, spec, specPathStats.Content)
}

func buildV1Service() (fs *fakesys.FakeFileSystem, specPath string, service concreteV1Service) {
	fs = fakesys.NewFakeFileSystem()
	specPath = "/spec.json"
	service = NewConcreteV1Service(fs, specPath)
	return
}
