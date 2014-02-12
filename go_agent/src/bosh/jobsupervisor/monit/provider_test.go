package monit_test

import (
	. "bosh/jobsupervisor/monit"
	fakeplatform "bosh/platform/fakes"
	"github.com/stretchr/testify/assert"
	"net/http"

	. "github.com/onsi/ginkgo"
	"time"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("get", func() {

			platform := fakeplatform.NewFakePlatform()

			platform.GetMonitCredentialsUsername = "fake-user"
			platform.GetMonitCredentialsPassword = "fake-pass"

			client, err := NewProvider(platform).Get()

			assert.NoError(GinkgoT(), err)

			expectedClient := NewHttpClient("127.0.0.1:2822", "fake-user", "fake-pass", http.DefaultClient, 1*time.Second)
			assert.Equal(GinkgoT(), expectedClient, client)
		})
	})
}
