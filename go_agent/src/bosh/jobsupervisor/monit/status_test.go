package monit_test

import (
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/jobsupervisor/monit"
	boshlog "bosh/logger"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("services in group returns slice of service", func() {

			expectedServices := []Service{
				{
					Monitored: true,
					Status:    "running",
				},
				{
					Monitored: false,
					Status:    "unknown",
				},
				{
					Monitored: true,
					Status:    "starting",
				},
				{
					Monitored: true,
					Status:    "failing",
				},
			}
			monitStatusFilePath, _ := filepath.Abs("../../../../fixtures/monit_status_with_multiple_services.xml")
			Expect(monitStatusFilePath).ToNot(BeNil())

			file, err := os.Open(monitStatusFilePath)
			Expect(err).ToNot(HaveOccurred())
			defer file.Close()

			handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				io.Copy(w, file)
				Expect(r.Method).To(Equal("GET"))
				Expect(r.URL.Path).To(Equal("/_status2"))
				Expect(r.URL.Query().Get("format")).To(Equal("xml"))
			})
			ts := httptest.NewServer(handler)
			defer ts.Close()

			logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
			client := NewHttpClient(ts.Listener.Addr().String(), "fake-user", "fake-pass", http.DefaultClient, 1*time.Millisecond, logger)

			status, err := client.Status()
			Expect(err).ToNot(HaveOccurred())

			services := status.ServicesInGroup("vcap")
			Expect(len(expectedServices)).To(Equal(len(services)))

			for i, expectedService := range expectedServices {
				Expect(expectedService).To(Equal(services[i]))
			}
		})
	})
}
