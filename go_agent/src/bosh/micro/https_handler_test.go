package micro_test

import (
	boshhandler "bosh/handler"
	boshlog "bosh/logger"
	. "bosh/micro"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	"crypto/tls"
	"errors"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"io/ioutil"
	"net/http"
	"net/url"
	"strings"
	"time"
)

var _ = Describe("HTTPSHandler", func() {
	var (
		serverURL       string
		handler         HTTPSHandler
		fs              *fakesys.FakeFileSystem
		receivedRequest boshhandler.Request
		httpClient      http.Client
	)

	BeforeEach(func() {
		serverURL = "https://user:pass@127.0.0.1:6900"
		mbusURL, _ := url.Parse(serverURL)
		logger := boshlog.NewLogger(boshlog.LevelNone)
		fs = fakesys.NewFakeFileSystem()
		dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
		handler = NewHTTPSHandler(mbusURL, logger, fs, dirProvider)

		go handler.Start(func(req boshhandler.Request) (resp boshhandler.Response) {
			receivedRequest = req
			return boshhandler.NewValueResponse("expected value")
		})

		httpTransport := &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}}
		httpClient = http.Client{Transport: httpTransport}
	})

	AfterEach(func() {
		handler.Stop()
		time.Sleep(1 * time.Millisecond)
	})

	Describe("POST /agent", func() {
		It("receives request and responds", func() {
			postBody := `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`
			postPayload := strings.NewReader(postBody)

			httpResponse, err := httpClient.Post(serverURL+"/agent", "application/json", postPayload)
			for err != nil {
				httpResponse, err = httpClient.Post(serverURL+"/agent", "application/json", postPayload)
			}
			defer httpResponse.Body.Close()

			Expect(receivedRequest.ReplyTo).To(Equal("reply to me!"))
			Expect(receivedRequest.Method).To(Equal("ping"))
			expectedPayload := []byte(postBody)
			Expect(receivedRequest.GetPayload()).To(Equal(expectedPayload))

			httpBody, readErr := ioutil.ReadAll(httpResponse.Body)
			Expect(readErr).ToNot(HaveOccurred())
			Expect(httpBody).To(Equal([]byte(`{"value":"expected value"}`)))
		})

		Context("when incorrect http method is used", func() {
			It("returns a 404", func() {
				waitForServerToStart(serverURL, "agent", httpClient)

				httpResponse, err := httpClient.Get(serverURL + "/agent")

				Expect(err).ToNot(HaveOccurred())
				Expect(httpResponse.StatusCode).To(Equal(404))
			})
		})
	})

	Describe("GET /blobs", func() {
		It("returns data from file system", func() {
			fs.WriteFileString("/var/vcap/micro_bosh/data/cache/123-456-789", "Some data")

			httpResponse, err := httpClient.Get(serverURL + "/blobs/a5/123-456-789")
			for err != nil {
				httpResponse, err = httpClient.Get(serverURL + "/blobs/a5/123-456-789")
			}
			defer httpResponse.Body.Close()

			httpBody, readErr := ioutil.ReadAll(httpResponse.Body)
			Expect(readErr).ToNot(HaveOccurred())
			Expect(httpResponse.StatusCode).To(Equal(200))
			Expect(httpBody).To(Equal([]byte("Some data")))
		})

		Context("when incorrect http method is used", func() {
			It("returns a 404", func() {
				waitForServerToStart(serverURL, "blobs", httpClient)

				postBody := `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`
				postPayload := strings.NewReader(postBody)

				httpResponse, err := httpClient.Post(serverURL+"/blobs/123", "application/json", postPayload)
				defer httpResponse.Body.Close()

				Expect(err).ToNot(HaveOccurred())
				Expect(httpResponse.StatusCode).To(Equal(404))
			})
		})

		Context("when file does not exist", func() {
			It("returns a 404", func() {
				waitForServerToStart(serverURL, "blobs", httpClient)

				httpResponse, err := httpClient.Get(serverURL + "/blobs/123")
				defer httpResponse.Body.Close()

				Expect(err).ToNot(HaveOccurred())
				Expect(httpResponse.StatusCode).To(Equal(404))
			})
		})
	})

	Describe("PUT /blobs", func() {
		It("updates the blob on the file system", func() {
			fs.WriteFileString("/var/vcap/micro_bosh/data/cache/123-456-789", "Some data")

			putBody := `Updated data`
			putPayload := strings.NewReader(putBody)

			waitForServerToStart(serverURL, "blobs", httpClient)

			request, err := http.NewRequest("PUT", serverURL+"/blobs/a5/123-456-789", putPayload)
			Expect(err).ToNot(HaveOccurred())

			httpResponse, err := httpClient.Do(request)
			defer httpResponse.Body.Close()

			Expect(err).ToNot(HaveOccurred())
			Expect(httpResponse.StatusCode).To(Equal(201))
			contents, err := fs.ReadFileString("/var/vcap/micro_bosh/data/cache/123-456-789")
			Expect(err).ToNot(HaveOccurred())
			Expect(contents).To(Equal("Updated data"))
		})

		Context("when manager errors", func() {
			It("returns a 500", func() {
				fs.WriteToFileError = errors.New("oops")

				putBody := `Updated data`
				putPayload := strings.NewReader(putBody)

				waitForServerToStart(serverURL, "blobs", httpClient)

				request, err := http.NewRequest("PUT", serverURL+"/blobs/a5/123-456-789", putPayload)
				Expect(err).ToNot(HaveOccurred())

				httpResponse, err := httpClient.Do(request)
				defer httpResponse.Body.Close()
				Expect(httpResponse.StatusCode).To(Equal(500))

				responseBody, err := ioutil.ReadAll(httpResponse.Body)
				Expect(err).ToNot(HaveOccurred())
				Expect(string(responseBody)).To(ContainSubstring("oops"))
			})
		})
	})

	Describe("routing and auth", func() {
		Context("when an incorrect uri is specificed", func() {
			It("returns a 404", func() {
				postBody := `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`
				postPayload := strings.NewReader(postBody)
				httpResponse, err := httpClient.Post(serverURL+"/bad_url", "application/json", postPayload)
				defer httpResponse.Body.Close()

				Expect(err).ToNot(HaveOccurred())
				Expect(httpResponse.StatusCode).To(Equal(404))
			})
		})

		Context("when an incorrect username/password was provided", func() {
			It("returns a 401", func() {
				postBody := `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`
				postPayload := strings.NewReader(postBody)
				httpResponse, err := httpClient.Post(strings.Replace(serverURL, "pass", "wrong", -1)+"/agent", "application/json", postPayload)
				defer httpResponse.Body.Close()

				Expect(err).ToNot(HaveOccurred())
				Expect(httpResponse.StatusCode).To(Equal(401))
				Expect(httpResponse.Header.Get("WWW-Authenticate")).To(Equal(`Basic realm=""`))
			})
		})
	})
})

func waitForServerToStart(serverURL string, endpoint string, httpClient http.Client) (httpResponse *http.Response) {
	postBody := `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`
	postPayload := strings.NewReader(postBody)

	httpResponse, err := httpClient.Post(serverURL+"/"+endpoint, "application/json", postPayload)
	for err != nil {
		httpResponse, err = httpClient.Post(serverURL+"/"+endpoint, "application/json", postPayload)
	}
	defer httpResponse.Body.Close()
	return
}
