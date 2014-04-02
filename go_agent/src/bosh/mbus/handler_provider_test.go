package mbus_test

import (
	"github.com/cloudfoundry/yagnats"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	boshlog "bosh/logger"
	. "bosh/mbus"
	"bosh/micro"
	fakeplatform "bosh/platform/fakes"
	boshdir "bosh/settings/directories"
	fakesettings "bosh/settings/fakes"
)

type providerDeps struct {
	settings    *fakesettings.FakeSettingsService
	platform    *fakeplatform.FakePlatform
	dirProvider boshdir.DirectoriesProvider
	logger      boshlog.Logger
}

func buildProvider(mbusUrl string) (deps providerDeps, provider MbusHandlerProvider) {
	deps.settings = &fakesettings.FakeSettingsService{MbusUrl: mbusUrl}
	deps.logger = boshlog.NewLogger(boshlog.LEVEL_NONE)
	provider = NewHandlerProvider(deps.settings, deps.logger)

	deps.platform = fakeplatform.NewFakePlatform()
	deps.dirProvider = boshdir.NewDirectoriesProvider("/var/vcap")
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("handler provider get returns nats handler", func() {
			deps, provider := buildProvider("nats://0.0.0.0")
			handler, err := provider.Get(deps.platform, deps.dirProvider)

			Expect(err).ToNot(HaveOccurred())
			assert.IsType(GinkgoT(), NewNatsHandler(deps.settings, deps.logger, yagnats.NewClient()), handler)
		})
		It("handler provider get returns https handler", func() {

			deps, provider := buildProvider("https://0.0.0.0")
			handler, err := provider.Get(deps.platform, deps.dirProvider)

			Expect(err).ToNot(HaveOccurred())
			assert.IsType(GinkgoT(), micro.HttpsHandler{}, handler)
		})
		It("handler provider get returns an error if not supported", func() {

			deps, provider := buildProvider("foo://0.0.0.0")
			_, err := provider.Get(deps.platform, deps.dirProvider)

			Expect(err).To(HaveOccurred())
		})
	})
}
