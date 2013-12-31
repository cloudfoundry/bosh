package monit

import (
	"encoding/base64"
	"fmt"
	"github.com/stretchr/testify/assert"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
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

	client := NewHttpClient(ts.Listener.Addr().String(), "fake-user", "fake-pass")

	err := client.StartService("test-service")
	assert.NoError(t, err)
	assert.True(t, calledMonit)
}

func TestStartServiceErrsWhenNon200Response(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("fake error message"))
	})
	ts := httptest.NewServer(handler)
	defer ts.Close()

	client := NewHttpClient(ts.Listener.Addr().String(), "fake-user", "fake-pass")

	err := client.StartService("test-service")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake error message")
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

	client := NewHttpClient(ts.Listener.Addr().String(), "fake-user", "fake-pass")

	err := client.StopService("test-service")
	assert.NoError(t, err)
	assert.True(t, calledMonit)
}

func TestStopServiceErrsWhenNon200Response(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("fake error message"))
	})
	ts := httptest.NewServer(handler)
	defer ts.Close()

	client := NewHttpClient(ts.Listener.Addr().String(), "fake-user", "fake-pass")

	err := client.StopService("test-service")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "fake error message")
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

	client := NewHttpClient(ts.Listener.Addr().String(), "fake-user", "fake-pass")

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

	client := NewHttpClient(ts.Listener.Addr().String(), "fake-user", "fake-pass")

	status, err := client.status()
	assert.NoError(t, err)
	assert.Equal(t, 2, len(status.Services.Services))
	assert.Equal(t, 1, status.Services.Services[0].Monitor)
	assert.Equal(t, "dummy", status.Services.Services[0].Name)
}
