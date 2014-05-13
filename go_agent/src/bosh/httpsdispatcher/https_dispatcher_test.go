package httpsdispatcher_test

import (
	"crypto/tls"
	"net/http"
	"net/url"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshdispatcher "bosh/httpsdispatcher"
	boshlog "bosh/logger"
)

var _ = Describe("HTTPSDispatcher", func() {
	var (
		dispatcher boshdispatcher.HTTPSDispatcher
	)

	BeforeEach(func() {
		serverURL, _ := url.Parse("https://127.0.0.1:7788")
		logger := boshlog.NewLogger(boshlog.LevelNone)
		dispatcher = boshdispatcher.NewHTTPSDispatcher(serverURL, logger)
		go dispatcher.Start()
		time.Sleep(1 * time.Second)
	})

	AfterEach(func() {
		dispatcher.Stop()
		time.Sleep(1 * time.Second)
	})

	It("calls the handler function for the route", func() {
		var hasBeenCalled = false
		handler := func(w http.ResponseWriter, r *http.Request) {
			hasBeenCalled = true
			w.WriteHeader(201)
		}

		dispatcher.AddRoute("/example", handler)

		client := getHTTPClient()
		response, err := client.Get("https://127.0.0.1:7788/example")

		Expect(err).To(BeNil())
		Expect(response.StatusCode).To(BeNumerically("==", 201))
		Expect(hasBeenCalled).To(Equal(true))
	})

	It("returns a 404 if the route does not exist", func() {
		client := getHTTPClient()
		response, _ := client.Get("https://127.0.0.1:7788/example")
		Expect(response.StatusCode).To(BeNumerically("==", 404))
	})
})

func getHTTPClient() (httpClient http.Client) {
	httpTransport := &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}}
	httpClient = http.Client{Transport: httpTransport}
	return
}
