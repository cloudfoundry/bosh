package infrastructure

import (
	"fmt"
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

	aws := newAwsInfrastructure(ts.URL)

	key, err := aws.GetPublicKey()
	assert.NoError(t, err)
	assert.Equal(t, key, expectedKey)
}

func TestGetSettingsWhenADnsIsNotProvided(t *testing.T) {
	expectedSettings := `{"agent_id":"my-agent-id"}`

	registryHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, r.Method, "GET")
		assert.Equal(t, r.URL.Path, "/instances/123-456-789/settings")
		w.Write([]byte(expectedSettings))
	})

	registryTs := httptest.NewServer(registryHandler)
	defer registryTs.Close()

	expectedUserData := fmt.Sprintf(`{"registry":{"endpoint":"%s"}}`, registryTs.URL)
	expectedInstanceId := "123-456-789"

	metadataHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, r.Method, "GET")

		switch r.URL.Path {
		case "/latest/user-data":
			w.Write([]byte(expectedUserData))
		case "/latest/meta-data/instance-id":
			w.Write([]byte(expectedInstanceId))
		}
	})

	metadataTs := httptest.NewServer(metadataHandler)
	defer metadataTs.Close()

	aws := newAwsInfrastructure(metadataTs.URL)

	settings, err := aws.GetSettings()
	assert.NoError(t, err)
	assert.Equal(t, settings, Settings{AgentId: "my-agent-id"})
}

// TODO handle dns being provided
