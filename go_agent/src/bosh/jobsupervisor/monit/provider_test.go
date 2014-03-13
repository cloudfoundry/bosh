package monit_test

import (
	. "bosh/jobsupervisor/monit"
	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
	"github.com/stretchr/testify/assert"
	"net/http"

	. "github.com/onsi/ginkgo"
	"time"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("get", func() {
			logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
			platform := fakeplatform.NewFakePlatform()

			platform.GetMonitCredentialsUsername = "fake-user"
			platform.GetMonitCredentialsPassword = "fake-pass"

			client, err := NewProvider(platform, logger).Get()

			assert.NoError(GinkgoT(), err)

			expectedClient := NewHttpClient("127.0.0.1:2822", "fake-user", "fake-pass", http.DefaultClient, 1*time.Second, logger)
			assert.Equal(GinkgoT(), expectedClient, client)
		})
	})
}
