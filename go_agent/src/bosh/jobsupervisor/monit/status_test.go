package monit_test

import (
	. "bosh/jobsupervisor/monit"
	"github.com/stretchr/testify/assert"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestServicesInGroupReturnsSliceOfService(t *testing.T) {
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

	client := NewHttpClient(ts.Listener.Addr().String(), "fake-user", "fake-pass", http.DefaultClient, 1*time.Millisecond)

	status, err := client.Status()
	assert.NoError(t, err)

	services := status.ServicesInGroup("vcap")
	assert.Equal(t, len(expectedServices), len(services))

	for i, expectedService := range expectedServices {
		assert.Equal(t, expectedService, services[i])
	}
}
