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

var _ = Describe("clientProvider", func() {
	It("Get", func() {
		logger := boshlog.NewLogger(boshlog.LevelNone)
		platform := fakeplatform.NewFakePlatform()

		platform.GetMonitCredentialsUsername = "fake-user"
		platform.GetMonitCredentialsPassword = "fake-pass"

		client, err := NewProvider(platform, logger).Get()

		Expect(err).ToNot(HaveOccurred())

		expectedClient := NewHTTPClient(
			"127.0.0.1:2822",
			"fake-user",
			"fake-pass",
			http.DefaultClient,
			1*time.Second,
			logger,
		)
		Expect(client).To(Equal(expectedClient))
	})
})
