package monit

import (
	"bosh/jobsupervisor/monit/http_fakes"
	"encoding/base64"
	"errors"
	"fmt"
	"github.com/stretchr/testify/assert"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestServicesInGroupReturnsServicesWhenFound(t *testing.T) {
}

func TestServicesInGroupErrorsWhenNotFound(t *testing.T) {
}

func TestStartService(t *testing.T) {
	var calledMonit bool

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calledMonit = true
		assert.Equal(t, r.Method, "POST")
		assert.Equal(t, r.URL.Path, "/test-service")
		assert.Equal(t, r.PostFormValue("action"), "start")
		assert.Equal(t, r.Header.Get("Content-Type"), "application/x-www-form-urlencoded")

		expectedAuthEncoded := base64.URLEncoding.EncodeToString([]byte("fake-user:fake-pass"))
		assert.Equal(t, r.Header.Get("Authorization"), fmt.Sprintf("Basic %s", expectedAuthEncoded))
	})
	ts := httptest.NewServer(handler)
	defer ts.Close()

	client := NewHttpClient(ts.Listener.Addr().String(), "fake-user", "fake-pass", http.DefaultClient)

	err := client.StartService("test-service")
	assert.NoError(t, err)
	assert.True(t, calledMonit)
}

func TestStartServiceRetriesWhenNon200Response(t *testing.T) {
	fakeHttpClient := http_fakes.NewFakeHttpClient()
	fakeHttpClient.StatusCode = 500
	fakeHttpClient.SetMessage("fake error message")

	client := NewHttpClient("agent.example.com", "fake-user", "fake-pass", fakeHttpClient)
	client.delayBetweenRetries = 1 * time.Millisecond

	err := client.StartService("test-service")
	assert.Equal(t, fakeHttpClient.CallCount, 20)
	assert.Error(t, err)
}

func TestStartServiceRetriesWhenConnectionRefused(t *testing.T) {
	fakeHttpClient := http_fakes.NewFakeHttpClient()
	fakeHttpClient.SetNilResponse()
	fakeHttpClient.Error = errors.New("some error")

	client := NewHttpClient("agent.example.com", "fake-user", "fake-pass", fakeHttpClient)
	client.delayBetweenRetries = 1 * time.Millisecond

	err := client.StartService("test-service")
	assert.Equal(t, fakeHttpClient.CallCount, 20)
	assert.Error(t, err)
}

func TestStopService(t *testing.T) {
	var calledMonit bool

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calledMonit = true
		assert.Equal(t, r.Method, "POST")
		assert.Equal(t, r.URL.Path, "/test-service")
		assert.Equal(t, r.PostFormValue("action"), "stop")
		assert.Equal(t, r.Header.Get("Content-Type"), "application/x-www-form-urlencoded")

		expectedAuthEncoded := base64.URLEncoding.EncodeToString([]byte("fake-user:fake-pass"))
		assert.Equal(t, r.Header.Get("Authorization"), fmt.Sprintf("Basic %s", expectedAuthEncoded))
	})
	ts := httptest.NewServer(handler)
	defer ts.Close()

	client := NewHttpClient(ts.Listener.Addr().String(), "fake-user", "fake-pass", http.DefaultClient)

	err := client.StopService("test-service")
	assert.NoError(t, err)
	assert.True(t, calledMonit)
}

func TestStopServiceRetriesWhenNon200Response(t *testing.T) {
	fakeHttpClient := http_fakes.NewFakeHttpClient()
	fakeHttpClient.StatusCode = 500
	fakeHttpClient.SetMessage("fake error message")

	client := NewHttpClient("agent.example.com", "fake-user", "fake-pass", fakeHttpClient)
	client.delayBetweenRetries = 1 * time.Millisecond

	err := client.StopService("test-service")
	assert.Equal(t, fakeHttpClient.CallCount, 20)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake error message")
}

func TestStopServiceRetriesWhenConnectionRefused(t *testing.T) {
	fakeHttpClient := http_fakes.NewFakeHttpClient()
	fakeHttpClient.SetNilResponse()
	fakeHttpClient.Error = errors.New("some error")

	client := NewHttpClient("agent.example.com", "fake-user", "fake-pass", fakeHttpClient)
	client.delayBetweenRetries = 1 * time.Millisecond

	err := client.StopService("test-service")
	assert.Equal(t, fakeHttpClient.CallCount, 20)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "some error")
}

func TestServicesInGroup(t *testing.T) {
	monitStatusFilePath, _ := filepath.Abs("../../../../fixtures/monit_status.xml")
	assert.NotNil(t, monitStatusFilePath)

	file, err := os.Open(monitStatusFilePath)
	assert.NoError(t, err)
	defer file.Close()

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.Copy(w, file)
		assert.Equal(t, r.Method, "GET")
		assert.Equal(t, r.URL.Path, "/_status2")
		assert.Equal(t, r.URL.Query().Get("format"), "xml")
	})
	ts := httptest.NewServer(handler)
	defer ts.Close()

	client := NewHttpClient(ts.Listener.Addr().String(), "fake-user", "fake-pass", http.DefaultClient)

	services, err := client.ServicesInGroup("vcap")
	assert.NoError(t, err)
	assert.Equal(t, []string{"dummy"}, services)
}

func TestDecodeStatus(t *testing.T) {
	monitStatusFilePath, _ := filepath.Abs("../../../../fixtures/monit_status.xml")
	assert.NotNil(t, monitStatusFilePath)

	file, err := os.Open(monitStatusFilePath)
	assert.NoError(t, err)
	defer file.Close()

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.Copy(w, file)
		assert.Equal(t, r.Method, "GET")
		assert.Equal(t, r.URL.Path, "/_status2")
		assert.Equal(t, r.URL.Query().Get("format"), "xml")
	})
	ts := httptest.NewServer(handler)
	defer ts.Close()

	client := NewHttpClient(ts.Listener.Addr().String(), "fake-user", "fake-pass", http.DefaultClient)

	status, err := client.status()
	assert.NoError(t, err)
	assert.Equal(t, 2, len(status.Services.Services))
	assert.Equal(t, 1, status.Services.Services[0].Monitor)
	assert.Equal(t, "dummy", status.Services.Services[0].Name)
}

func TestStatusRetriesWhenNon200Response(t *testing.T) {
	fakeHttpClient := http_fakes.NewFakeHttpClient()
	fakeHttpClient.StatusCode = 500
	fakeHttpClient.SetMessage("fake error message")

	client := NewHttpClient("agent.example.com", "fake-user", "fake-pass", fakeHttpClient)
	client.delayBetweenRetries = 1 * time.Millisecond

	_, err := client.Status()
	assert.Equal(t, fakeHttpClient.CallCount, 20)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake error message")
}

func TestStatusRetriesWhenConnectionRefused(t *testing.T) {
	fakeHttpClient := http_fakes.NewFakeHttpClient()
	fakeHttpClient.SetNilResponse()
	fakeHttpClient.Error = errors.New("some error")

	client := NewHttpClient("agent.example.com", "fake-user", "fake-pass", fakeHttpClient)
	client.delayBetweenRetries = 1 * time.Millisecond

	_, err := client.Status()
	assert.Equal(t, fakeHttpClient.CallCount, 20)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "some error")
}
