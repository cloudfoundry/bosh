package infrastructure

import (
	"fmt"
	"github.com/stretchr/testify/assert"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
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

	aws := newAwsInfrastructure(ts.URL, &FakeDnsResolver{})

	key, err := aws.GetPublicKey()
	assert.NoError(t, err)
	assert.Equal(t, key, expectedKey)
}

func TestGetSettingsWhenADnsIsNotProvided(t *testing.T) {
	registryTs, _ := spinUpRegistry(t)
	defer registryTs.Close()

	expectedUserData := fmt.Sprintf(`{"registry":{"endpoint":"%s"}}`, registryTs.URL)

	metadataTs := spinUpMetadaServer(t, expectedUserData)
	defer metadataTs.Close()

	aws := newAwsInfrastructure(metadataTs.URL, &FakeDnsResolver{})

	settings, err := aws.GetSettings()
	assert.NoError(t, err)
	assert.Equal(t, settings, Settings{AgentId: "my-agent-id"})
}

func TestGetSettingsWhenDnsServersAreProvided(t *testing.T) {
	fakeDnsResolver := &FakeDnsResolver{
		LookupHostIp: "127.0.0.1",
	}

	registryTs, registryTsPort := spinUpRegistry(t)
	defer registryTs.Close()

	expectedUserData := fmt.Sprintf(`
		{
			"registry":{
				"endpoint":"http://the.registry.name:%s"
			},
			"dns":{
				"nameserver": ["8.8.8.8", "9.9.9.9"]
			}
		}`,
		registryTsPort)

	metadataTs := spinUpMetadaServer(t, expectedUserData)
	defer metadataTs.Close()

	aws := newAwsInfrastructure(metadataTs.URL, fakeDnsResolver)

	settings, err := aws.GetSettings()
	assert.NoError(t, err)
	assert.Equal(t, settings, Settings{AgentId: "my-agent-id"})
	assert.Equal(t, fakeDnsResolver.LookupHostHost, "the.registry.name")
	assert.Equal(t, fakeDnsResolver.LookupHostDnsServers, []string{"8.8.8.8", "9.9.9.9"})
}

// Fake Dns Resolver

type FakeDnsResolver struct {
	LookupHostIp         string
	LookupHostDnsServers []string
	LookupHostHost       string
}

func (res *FakeDnsResolver) LookupHost(dnsServers []string, host string) (ip string, err error) {
	res.LookupHostDnsServers = dnsServers
	res.LookupHostHost = host
	ip = res.LookupHostIp
	return
}

// Server methods

func spinUpRegistry(t *testing.T) (ts *httptest.Server, port string) {
	settings := `{"settings": "{\"agent_id\":\"my-agent-id\"}"}`

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, r.Method, "GET")
		assert.Equal(t, r.URL.Path, "/instances/123-456-789/settings")
		w.Write([]byte(settings))
	})

	ts = httptest.NewServer(handler)

	registryUrl, err := url.Parse(ts.URL)
	assert.NoError(t, err)
	port = strings.Split(registryUrl.Host, ":")[1]

	return
}

func spinUpMetadaServer(t *testing.T, userData string) (ts *httptest.Server) {
	instanceId := "123-456-789"

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, r.Method, "GET")

		switch r.URL.Path {
		case "/latest/user-data":
			w.Write([]byte(userData))
		case "/latest/meta-data/instance-id":
			w.Write([]byte(instanceId))
		}
	})

	ts = httptest.NewServer(handler)
	return
}
