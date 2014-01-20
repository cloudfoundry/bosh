package micro

import (
	boshhandler "bosh/handler"
	boshlog "bosh/logger"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	"crypto/tls"
	"github.com/stretchr/testify/assert"
	"io/ioutil"
	"net/http"
	"net/url"
	"strings"
	"testing"
)

func TestStartAgentEndpoint(t *testing.T) {
	serverURL, handler, _ := startServer()
	defer stopServer(handler)

	postBody := `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`
	postPayload := strings.NewReader(postBody)
	client := getHTTPClient()

	httpResponse, err := client.Post(serverURL+"/agent", "application/json", postPayload)
	for err != nil {
		httpResponse, err = client.Post(serverURL+"/agent", "application/json", postPayload)
	}
	defer httpResponse.Body.Close()

	assert.Equal(t, receivedRequest.ReplyTo, "reply to me!")
	assert.Equal(t, receivedRequest.Method, "ping")
	expectedPayload := []byte(postBody)
	assert.Equal(t, receivedRequest.GetPayload(), expectedPayload)

	httpBody, readErr := ioutil.ReadAll(httpResponse.Body)
	assert.NoError(t, readErr)
	assert.Equal(t, httpBody, []byte(`{"value":"expected value"}`))
}

func TestStartAgentEndpointWithIncorrectHTTPMethod(t *testing.T) {
	serverURL, handler, _ := startServer()
	defer stopServer(handler)

	waitForServerToStart(serverURL, "agent")

	client := getHTTPClient()
	httpResponse, err := client.Get(serverURL + "/agent")
	defer httpResponse.Body.Close()

	assert.NoError(t, err)
	assert.Equal(t, httpResponse.StatusCode, 404)
}

func TestStartBlobsEndpointWithIncorrectHTTPMethod(t *testing.T) {
	serverURL, handler, _ := startServer()
	defer stopServer(handler)

	waitForServerToStart(serverURL, "blobs")

	postBody := `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`
	postPayload := strings.NewReader(postBody)
	client := getHTTPClient()

	httpResponse, err := client.Post(serverURL+"/blobs/123", "application/json", postPayload)
	defer httpResponse.Body.Close()

	assert.NoError(t, err)
	assert.Equal(t, httpResponse.StatusCode, 404)
}

func TestStartBlobsEndpoint(t *testing.T) {
	serverURL, handler, fakeFs := startServer()
	defer stopServer(handler)
	fakeFs.WriteToFile("/var/vcap/micro_bosh/data/cache/123-456-789", "Some data")

	client := getHTTPClient()

	httpResponse, err := client.Get(serverURL + "/blobs/a5/123-456-789")
	for err != nil {
		httpResponse, err = client.Get(serverURL + "/blobs/a5/123-456-789")
	}
	defer httpResponse.Body.Close()

	httpBody, readErr := ioutil.ReadAll(httpResponse.Body)
	assert.NoError(t, readErr)
	assert.Equal(t, httpResponse.StatusCode, 200)
	assert.Equal(t, httpBody, []byte("Some data"))
}

func TestStartBlobsEndpointWhenFileNotFound(t *testing.T) {
	serverURL, handler, _ := startServer()
	defer stopServer(handler)

	waitForServerToStart(serverURL, "blobs")

	client := getHTTPClient()

	httpResponse, err := client.Get(serverURL + "/blobs/123")
	defer httpResponse.Body.Close()

	assert.NoError(t, err)
	assert.Equal(t, httpResponse.StatusCode, 404)
}

func TestStartWithIncorrectURIPath(t *testing.T) {
	serverURL, handler, _ := startServer()
	defer stopServer(handler)

	waitForServerToStart(serverURL, "agent")

	postBody := `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`
	postPayload := strings.NewReader(postBody)
	client := getHTTPClient()
	httpResponse, err := client.Post(serverURL+"/bad_url", "application/json", postPayload)
	defer httpResponse.Body.Close()

	assert.NoError(t, err)
	assert.Equal(t, httpResponse.StatusCode, 404)
}

func TestStartWithIncorrectUsernameAndPassword(t *testing.T) {
	serverURL, handler, _ := startServer()
	defer stopServer(handler)

	waitForServerToStart(serverURL, "agent")

	postBody := `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`
	postPayload := strings.NewReader(postBody)
	client := getHTTPClient()
	httpResponse, err := client.Post(strings.Replace(serverURL, "pass", "wrong", -1)+"/agent", "application/json", postPayload)
	defer httpResponse.Body.Close()

	assert.NoError(t, err)
	assert.Equal(t, httpResponse.StatusCode, 401)
	assert.Equal(t, httpResponse.Header.Get("WWW-Authenticate"), `Basic realm=""`)
}

func getHTTPClient() (httpClient http.Client) {
	httpTransport := &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}}
	httpClient = http.Client{Transport: httpTransport}
	return
}

func waitForServerToStart(serverURL string, endpoint string) (httpResponse *http.Response) {
	postBody := `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`
	postPayload := strings.NewReader(postBody)
	client := getHTTPClient()

	httpResponse, err := client.Post(serverURL+"/"+endpoint, "application/json", postPayload)
	for err != nil {
		httpResponse, err = client.Post(serverURL+"/"+endpoint, "application/json", postPayload)
	}
	defer httpResponse.Body.Close()
	return
}

var receivedRequest boshhandler.Request

func startServer() (serverURL string, handler HttpsHandler, fs *fakesys.FakeFileSystem) {
	serverURL = "https://user:pass@127.0.0.1:6900"
	mbusUrl, _ := url.Parse(serverURL)
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	fs = fakesys.NewFakeFileSystem()
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
	handler = NewHttpsHandler(mbusUrl, logger, fs, dirProvider)

	go handler.Start(func(req boshhandler.Request) (resp boshhandler.Response) {
		receivedRequest = req
		return boshhandler.NewValueResponse("expected value")
	})
	return
}

func stopServer(handler HttpsHandler) {
	handler.Stop()
}
