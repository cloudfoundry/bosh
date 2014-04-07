package monit_test

import (
	"net/http"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/jobsupervisor/monit"
	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("get", func() {
			logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
			platform := fakeplatform.NewFakePlatform()

			platform.GetMonitCredentialsUsername = "fake-user"
			platform.GetMonitCredentialsPassword = "fake-pass"

			client, err := NewProvider(platform, logger).Get()

			Expect(err).ToNot(HaveOccurred())

			expectedClient := NewHTTPClient("127.0.0.1:2822", "fake-user", "fake-pass", http.DefaultClient, 1*time.Second, logger)
			Expect(expectedClient).To(Equal(client))
		})
	})
}
