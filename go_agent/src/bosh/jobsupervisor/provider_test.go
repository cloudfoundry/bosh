package jobsupervisor

import (
	fakemonit "bosh/jobsupervisor/monit/fakes"
	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
	boshdir "bosh/settings/directories"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetMonitJobSupervisor(t *testing.T) {
	deps, provider := buildProvider()

	actualSupervisor, err := provider.Get("monit")
	assert.NoError(t, err)

	expectedSupervisor := NewMonitJobSupervisor(deps.platform.Fs, deps.platform.Runner, deps.client, deps.logger, deps.dirProvider)
	assert.Equal(t, expectedSupervisor, actualSupervisor)
}

func TestGetDummyJobSupervisor(t *testing.T) {
	_, provider := buildProvider()

	actualSupervisor, err := provider.Get("dummy")
	assert.NoError(t, err)

	expectedSupervisor := newDummyJobSupervisor()
	assert.Equal(t, expectedSupervisor, actualSupervisor)
}

func TestGetErrsWhenNotFound(t *testing.T) {
	_, provider := buildProvider()

	_, err := provider.Get("does-not-exist")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does-not-exist could not be found")
}

type providerDependencies struct {
	platform    *fakeplatform.FakePlatform
	client      *fakemonit.FakeMonitClient
	logger      boshlog.Logger
	dirProvider boshdir.DirectoriesProvider
}

func buildProvider() (
	deps providerDependencies,
	provider provider,
) {
	deps.platform = fakeplatform.NewFakePlatform()
	deps.client = fakemonit.NewFakeMonitClient()
	deps.logger = boshlog.NewLogger(boshlog.LEVEL_NONE)
	deps.dirProvider = boshdir.NewDirectoriesProvider("/fake-base-dir")

	provider = NewProvider(
		deps.platform,
		deps.client,
		deps.logger,
		deps.dirProvider,
	)
	return
}
