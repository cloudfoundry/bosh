package agent

import (
	"github.com/stretchr/testify/assert"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGetPublicKey(t *testing.T) {
	expectedKey := "some public key"

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, r.Method, "GET")
		assert.Equal(t, r.URL.Path, "/latest/meta-data/public-keys/0/openssh-key")
		w.Write([]byte(expectedKey))
	})

	ts := httptest.NewServer(handler)
	defer ts.Close()

	aws := NewAwsInfrastructure(ts.URL)

	key, err := aws.GetPublicKey()
	assert.NoError(t, err)
	assert.Equal(t, key, expectedKey)
}
