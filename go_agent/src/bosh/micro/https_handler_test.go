package micro

import (
	boshhandler "bosh/handler"
	boshlog "bosh/logger"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	"crypto/tls"
	"errors"
	"github.com/stretchr/testify/assert"
	"io/ioutil"
	"net/http"
	"net/url"
	"strings"
	"testing"
)

/********** POST /agent *************/

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

/********** GET /blobs *************/

func TestStartGETBlobsEndpoint(t *testing.T) {
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

func TestStartGETBlobsEndpointWithIncorrectHTTPMethod(t *testing.T) {
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

func TestStartGETBlobsEndpointWhenFileNotFound(t *testing.T) {
	serverURL, handler, _ := startServer()
	defer stopServer(handler)

	waitForServerToStart(serverURL, "blobs")

	client := getHTTPClient()

	httpResponse, err := client.Get(serverURL + "/blobs/123")
	defer httpResponse.Body.Close()

	assert.NoError(t, err)
	assert.Equal(t, httpResponse.StatusCode, 404)
}

/********** PUT /blobs *************/

func TestStartPUTBlobsEndpoint(t *testing.T) {
	serverURL, handler, fakeFs := startServer()
	defer stopServer(handler)
	fakeFs.WriteToFile("/var/vcap/micro_bosh/data/cache/123-456-789", "Some data")

	putBody := `Updated data`
	putPayload := strings.NewReader(putBody)
	client := getHTTPClient()

	waitForServerToStart(serverURL, "blobs")

	request, err := http.NewRequest("PUT", serverURL+"/blobs/a5/123-456-789", putPayload)
	assert.NoError(t, err)

	httpResponse, err := client.Do(request)
	defer httpResponse.Body.Close()

	assert.NoError(t, err)
	assert.Equal(t, httpResponse.StatusCode, 201)
	contents, err := fakeFs.ReadFile("/var/vcap/micro_bosh/data/cache/123-456-789")
	assert.NoError(t, err)
	assert.Equal(t, contents, "Updated data")
}

func TestStartPUTBlobsEndpoint500WhenManagerErrs(t *testing.T) {
	serverURL, handler, fs := startServer()
	defer stopServer(handler)

	fs.WriteToFileError = errors.New("oops")

	putBody := `Updated data`
	putPayload := strings.NewReader(putBody)
	client := getHTTPClient()

	waitForServerToStart(serverURL, "blobs")

	request, err := http.NewRequest("PUT", serverURL+"/blobs/a5/123-456-789", putPayload)
	assert.NoError(t, err)

	httpResponse, err := client.Do(request)
	defer httpResponse.Body.Close()
	assert.Equal(t, httpResponse.StatusCode, 500)

	responseBody, err := ioutil.ReadAll(httpResponse.Body)
	assert.NoError(t, err)
	assert.Contains(t, string(responseBody), "oops")
}

/********** defaults *************/

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
