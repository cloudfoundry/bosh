package jobsupervisor

import (
	fakemonit "bosh/jobsupervisor/monit/fakes"
	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
	boshdir "bosh/settings/directories"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

type providerDependencies struct {
	platform              *fakeplatform.FakePlatform
	client                *fakemonit.FakeMonitClient
	logger                boshlog.Logger
	dirProvider           boshdir.DirectoriesProvider
	jobFailuresServerPort int
}

func buildProvider() (
	deps providerDependencies,
	provider provider,
) {
	deps.platform = fakeplatform.NewFakePlatform()
	deps.client = fakemonit.NewFakeMonitClient()
	deps.logger = boshlog.NewLogger(boshlog.LEVEL_NONE)
	deps.dirProvider = boshdir.NewDirectoriesProvider("/fake-base-dir")
	deps.jobFailuresServerPort = 2825

	provider = NewProvider(
		deps.platform,
		deps.client,
		deps.logger,
		deps.dirProvider,
	)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("get monit job supervisor", func() {
			deps, provider := buildProvider()

			actualSupervisor, err := provider.Get("monit")
			assert.NoError(GinkgoT(), err)

			expectedSupervisor := NewMonitJobSupervisor(deps.platform.Fs, deps.platform.Runner, deps.client, deps.logger, deps.dirProvider, deps.jobFailuresServerPort)
			assert.Equal(GinkgoT(), expectedSupervisor, actualSupervisor)
		})
		It("get dummy job supervisor", func() {

			_, provider := buildProvider()

			actualSupervisor, err := provider.Get("dummy")
			assert.NoError(GinkgoT(), err)

			expectedSupervisor := newDummyJobSupervisor()
			assert.Equal(GinkgoT(), expectedSupervisor, actualSupervisor)
		})
		It("get errs when not found", func() {

			_, provider := buildProvider()

			_, err := provider.Get("does-not-exist")
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "does-not-exist could not be found")
		})
	})
}
