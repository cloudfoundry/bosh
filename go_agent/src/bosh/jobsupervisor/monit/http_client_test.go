package monit_test

import (
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/jobsupervisor/monit"
	fakemonit "bosh/jobsupervisor/monit/fakes"
	boshlog "bosh/logger"
)

func init() {
	Describe("httpClient", func() {
		var (
			logger = boshlog.NewLogger(boshlog.LevelNone)
		)

		It("services in group returns services when found", func() {})

		It("services in group errors when not found", func() {})

		Describe("StartService", func() {
			It("start service", func() {
				var calledMonit bool

				handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					calledMonit = true
					Expect(r.Method).To(Equal("POST"))
					Expect(r.URL.Path).To(Equal("/test-service"))
					Expect(r.PostFormValue("action")).To(Equal("start"))
					Expect(r.Header.Get("Content-Type")).To(Equal("application/x-www-form-urlencoded"))

					expectedAuthEncoded := base64.URLEncoding.EncodeToString([]byte("fake-user:fake-pass"))
					Expect(r.Header.Get("Authorization")).To(Equal(fmt.Sprintf("Basic %s", expectedAuthEncoded)))
				})
				ts := httptest.NewServer(handler)
				defer ts.Close()

				client := NewHTTPClient(ts.Listener.Addr().String(), "fake-user", "fake-pass", http.DefaultClient, 1*time.Millisecond, logger)

				err := client.StartService("test-service")
				Expect(err).ToNot(HaveOccurred())
				Expect(calledMonit).To(BeTrue())
			})

			It("start service retries when non200 response", func() {
				fakeHTTPClient := fakemonit.NewFakeHTTPClient()
				fakeHTTPClient.StatusCode = 500
				fakeHTTPClient.SetMessage("fake error message")

				client := NewHTTPClient("agent.example.com", "fake-user", "fake-pass", fakeHTTPClient, 1*time.Millisecond, logger)

				err := client.StartService("test-service")
				Expect(fakeHTTPClient.CallCount).To(Equal(20))
				Expect(err).To(HaveOccurred())
			})

			It("start service retries when connection refused", func() {
				fakeHTTPClient := fakemonit.NewFakeHTTPClient()
				fakeHTTPClient.SetNilResponse()
				fakeHTTPClient.Error = errors.New("some error")

				client := NewHTTPClient("agent.example.com", "fake-user", "fake-pass", fakeHTTPClient, 1*time.Millisecond, logger)

				err := client.StartService("test-service")
				Expect(fakeHTTPClient.CallCount).To(Equal(20))
				Expect(err).To(HaveOccurred())
			})
		})

		Describe("StopService", func() {
			It("stop service", func() {
				var calledMonit bool

				handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					calledMonit = true
					Expect(r.Method).To(Equal("POST"))
					Expect(r.URL.Path).To(Equal("/test-service"))
					Expect(r.PostFormValue("action")).To(Equal("stop"))
					Expect(r.Header.Get("Content-Type")).To(Equal("application/x-www-form-urlencoded"))

					expectedAuthEncoded := base64.URLEncoding.EncodeToString([]byte("fake-user:fake-pass"))
					Expect(r.Header.Get("Authorization")).To(Equal(fmt.Sprintf("Basic %s", expectedAuthEncoded)))
				})
				ts := httptest.NewServer(handler)
				defer ts.Close()

				client := NewHTTPClient(ts.Listener.Addr().String(), "fake-user", "fake-pass", http.DefaultClient, 1*time.Millisecond, logger)

				err := client.StopService("test-service")
				Expect(err).ToNot(HaveOccurred())
				Expect(calledMonit).To(BeTrue())
			})

			It("stop service retries when non200 response", func() {
				fakeHTTPClient := fakemonit.NewFakeHTTPClient()
				fakeHTTPClient.StatusCode = 500
				fakeHTTPClient.SetMessage("fake error message")

				client := NewHTTPClient("agent.example.com", "fake-user", "fake-pass", fakeHTTPClient, 1*time.Millisecond, logger)

				err := client.StopService("test-service")
				Expect(fakeHTTPClient.CallCount).To(Equal(20))
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake error message"))
			})

			It("stop service retries when connection refused", func() {
				fakeHTTPClient := fakemonit.NewFakeHTTPClient()
				fakeHTTPClient.SetNilResponse()
				fakeHTTPClient.Error = errors.New("some error")

				client := NewHTTPClient("agent.example.com", "fake-user", "fake-pass", fakeHTTPClient, 1*time.Millisecond, logger)

				err := client.StopService("test-service")
				Expect(fakeHTTPClient.CallCount).To(Equal(20))
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("some error"))
			})
		})

		Describe("UnmonitorService", func() {
			It("issues a call to unmontor service by name", func() {
				var calledMonit bool

				handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					calledMonit = true
					Expect(r.Method).To(Equal("POST"))
					Expect(r.URL.Path).To(Equal("/test-service"))
					Expect(r.PostFormValue("action")).To(Equal("unmonitor"))
					Expect(r.Header.Get("Content-Type")).To(Equal("application/x-www-form-urlencoded"))

					expectedAuthEncoded := base64.URLEncoding.EncodeToString([]byte("fake-user:fake-pass"))
					Expect(r.Header.Get("Authorization")).To(Equal(fmt.Sprintf("Basic %s", expectedAuthEncoded)))
				})

				ts := httptest.NewServer(handler)
				defer ts.Close()

				client := NewHTTPClient(ts.Listener.Addr().String(), "fake-user", "fake-pass", http.DefaultClient, 1*time.Millisecond, logger)

				err := client.UnmonitorService("test-service")
				Expect(err).ToNot(HaveOccurred())
				Expect(calledMonit).To(BeTrue())
			})

			It("retries when non200 response", func() {
				fakeHTTPClient := fakemonit.NewFakeHTTPClient()
				fakeHTTPClient.StatusCode = 500
				fakeHTTPClient.SetMessage("fake-http-response-message")

				client := NewHTTPClient("agent.example.com", "fake-user", "fake-pass", fakeHTTPClient, 1*time.Millisecond, logger)

				err := client.UnmonitorService("test-service")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-http-response-message"))

				Expect(fakeHTTPClient.CallCount).To(Equal(20))
			})

			It("retries when connection refused", func() {
				fakeHTTPClient := fakemonit.NewFakeHTTPClient()
				fakeHTTPClient.SetNilResponse()
				fakeHTTPClient.Error = errors.New("fake-http-error")

				client := NewHTTPClient("agent.example.com", "fake-user", "fake-pass", fakeHTTPClient, 1*time.Millisecond, logger)

				err := client.UnmonitorService("test-service")
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-http-error"))

				Expect(fakeHTTPClient.CallCount).To(Equal(20))
			})
		})

		Describe("ServicesInGroup", func() {
			It("services in group", func() {
				monitStatusFilePath, _ := filepath.Abs("../../../../fixtures/monit_status.xml")
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

				client := NewHTTPClient(ts.Listener.Addr().String(), "fake-user", "fake-pass", http.DefaultClient, 1*time.Millisecond, logger)

				services, err := client.ServicesInGroup("vcap")
				Expect(err).ToNot(HaveOccurred())
				Expect([]string{"dummy"}).To(Equal(services))
			})
		})

		Describe("Status", func() {
			It("decode status", func() {
				monitStatusFilePath, _ := filepath.Abs("../../../../fixtures/monit_status.xml")
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

				client := NewHTTPClient(ts.Listener.Addr().String(), "fake-user", "fake-pass", http.DefaultClient, 1*time.Millisecond, logger)

				status, err := client.Status()
				Expect(err).ToNot(HaveOccurred())
				dummyServices := status.ServicesInGroup("vcap")
				Expect(1).To(Equal(len(dummyServices)))
			})

			It("status retries when non200 response", func() {
				fakeHTTPClient := fakemonit.NewFakeHTTPClient()
				fakeHTTPClient.StatusCode = 500
				fakeHTTPClient.SetMessage("fake error message")

				client := NewHTTPClient("agent.example.com", "fake-user", "fake-pass", fakeHTTPClient, 1*time.Millisecond, logger)

				_, err := client.Status()
				Expect(fakeHTTPClient.CallCount).To(Equal(20))
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake error message"))
			})

			It("status retries when connection refused", func() {
				fakeHTTPClient := fakemonit.NewFakeHTTPClient()
				fakeHTTPClient.SetNilResponse()
				fakeHTTPClient.Error = errors.New("some error")

				client := NewHTTPClient("agent.example.com", "fake-user", "fake-pass", fakeHTTPClient, 1*time.Millisecond, logger)

				err := client.StartService("hello")
				Expect(fakeHTTPClient.CallCount).To(Equal(20))
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("some error"))

				for _, req := range fakeHTTPClient.RequestBodies {
					Expect(req).To(Equal("action=start"))
				}
			})
		})
	})
}
