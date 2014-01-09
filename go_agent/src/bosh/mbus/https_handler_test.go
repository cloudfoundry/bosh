package mbus

import (
	boshlog "bosh/logger"
	"crypto/tls"
	"fmt"
	"github.com/stretchr/testify/assert"
	"io/ioutil"
	"net/http"
	"net/url"
	"strings"
	"testing"
)

func TestStart(t *testing.T) {
	serverURL := startServer()

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

func TestStartWithIncorrectHTTPMethod(t *testing.T) {
	serverURL := startServer()
	waitForServerToStart(serverURL)

	client := getHTTPClient()
	httpResponse, err := client.Get(serverURL + "/agent")
	defer httpResponse.Body.Close()

	assert.NoError(t, err)
	assert.Equal(t, httpResponse.StatusCode, 404)
}

func TestStartWithIncorrectURIPath(t *testing.T) {
	serverURL := startServer()
	waitForServerToStart(serverURL)

	postBody := `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`
	postPayload := strings.NewReader(postBody)
	client := getHTTPClient()
	httpResponse, err := client.Post(serverURL+"/bad_url", "application/json", postPayload)
	defer httpResponse.Body.Close()

	assert.NoError(t, err)
	assert.Equal(t, httpResponse.StatusCode, 404)
}

func TestStartWithIncorrectUsernameAndPassword(t *testing.T) {
	serverURL := startServer()
	waitForServerToStart(serverURL)

	postBody := `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`
	postPayload := strings.NewReader(postBody)
	client := getHTTPClient()
	httpResponse, err := client.Post(strings.Replace(serverURL, "pass", "wrong", -1)+"/agent", "application/json", postPayload)
	defer httpResponse.Body.Close()

	assert.NoError(t, err)
	assert.Equal(t, httpResponse.StatusCode, 401)
}

var httpsHandlerPort int = 6900

func getHttpsHandlerPort() int {
	httpsHandlerPort++
	return httpsHandlerPort
}

func getHTTPClient() (httpClient http.Client) {
	httpTransport := &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}}
	httpClient = http.Client{Transport: httpTransport}
	return
}

func waitForServerToStart(serverURL string) (httpResponse *http.Response) {
	postBody := `{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`
	postPayload := strings.NewReader(postBody)
	client := getHTTPClient()

	httpResponse, err := client.Post(serverURL+"/agent", "application/json", postPayload)
	for err != nil {
		httpResponse, err = client.Post(serverURL+"/agent", "application/json", postPayload)
	}
	defer httpResponse.Body.Close()
	return
}

var receivedRequest Request

func startServer() (serverURL string) {
	port := getHttpsHandlerPort()
	serverURL = fmt.Sprintf("https://user:pass@127.0.0.1:%d", port)

	mbusUrl, _ := url.Parse(serverURL)
	logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
	handler := newHttpsHandler(mbusUrl, logger)

	go handler.Start(func(req Request) (resp Response) {
		receivedRequest = req
		return NewValueResponse("expected value")
	})
	defer handler.Stop()
	return
}
