package infrastructure

import (
	boshsettings "bosh/settings"
	"fmt"
	"github.com/stretchr/testify/assert"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func TestAwsSetupSsh(t *testing.T) {
	expectedKey := "some public key"

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, r.Method, "GET")
		assert.Equal(t, r.URL.Path, "/latest/meta-data/public-keys/0/openssh-key")
		w.Write([]byte(expectedKey))
	})

	ts := httptest.NewServer(handler)
	defer ts.Close()

	aws := newAwsInfrastructure(ts.URL, &FakeDnsResolver{})

	fakeSshSetupDelegate := &FakeSshSetupDelegate{}

	err := aws.SetupSsh(fakeSshSetupDelegate, "vcap")
	assert.NoError(t, err)

	assert.Equal(t, fakeSshSetupDelegate.SetupSshPublicKey, expectedKey)
	assert.Equal(t, fakeSshSetupDelegate.SetupSshUsername, "vcap")
}

func TestAwsGetSettingsWhenADnsIsNotProvided(t *testing.T) {
	registryTs, _, expectedSettings := spinUpAwsRegistry(t)
	defer registryTs.Close()

	expectedUserData := fmt.Sprintf(`{"registry":{"endpoint":"%s"}}`, registryTs.URL)

	metadataTs := spinUpAwsMetadataServer(t, expectedUserData)
	defer metadataTs.Close()

	aws := newAwsInfrastructure(metadataTs.URL, &FakeDnsResolver{})

	settings, err := aws.GetSettings()
	assert.NoError(t, err)
	assert.Equal(t, settings, expectedSettings)
}

func TestAwsGetSettingsWhenDnsServersAreProvided(t *testing.T) {
	fakeDnsResolver := &FakeDnsResolver{
		LookupHostIp: "127.0.0.1",
	}

	registryTs, registryTsPort, expectedSettings := spinUpAwsRegistry(t)
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

	metadataTs := spinUpAwsMetadataServer(t, expectedUserData)
	defer metadataTs.Close()

	aws := newAwsInfrastructure(metadataTs.URL, fakeDnsResolver)

	settings, err := aws.GetSettings()
	assert.NoError(t, err)
	assert.Equal(t, settings, expectedSettings)
	assert.Equal(t, fakeDnsResolver.LookupHostHost, "the.registry.name")
	assert.Equal(t, fakeDnsResolver.LookupHostDnsServers, []string{"8.8.8.8", "9.9.9.9"})
}

func TestAwsSetupNetworking(t *testing.T) {
	fakeDnsResolver := &FakeDnsResolver{}
	aws := newAwsInfrastructure("", fakeDnsResolver)
	fakeDelegate := &FakeNetworkingDelegate{}
	networks := boshsettings.Networks{"bosh": boshsettings.Network{}}

	aws.SetupNetworking(fakeDelegate, networks)

	assert.Equal(t, fakeDelegate.SetupDhcpNetworks, networks)
}

// Fake Ssh Setup Delegate

type FakeSshSetupDelegate struct {
	SetupSshPublicKey string
	SetupSshUsername  string
}

func (d *FakeSshSetupDelegate) SetupSsh(publicKey, username string) (err error) {
	d.SetupSshPublicKey = publicKey
	d.SetupSshUsername = username
	return
}

// Fake Networking Delegate

type FakeNetworkingDelegate struct {
	SetupDhcpNetworks boshsettings.Networks
}

func (d *FakeNetworkingDelegate) SetupDhcp(networks boshsettings.Networks) (err error) {
	d.SetupDhcpNetworks = networks
	return
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

func spinUpAwsRegistry(t *testing.T) (ts *httptest.Server, port string, expectedSettings boshsettings.Settings) {
	settingsJson := `{
		"agent_id": "my-agent-id",
		"blobstore": {
			"options": {
				"bucket_name": "george",
				"encryption_key": "optional encryption key",
				"access_key_id": "optional access key id",
				"secret_access_key": "optional secret access key"
			},
			"provider": "s3"
		},
		"disks": {
			"ephemeral": "/dev/sdb",
			"persistent": {
				"vol-xxxxxx": "/dev/sdf"
			},
			"system": "/dev/sda1"
		},
		"env": {
			"bosh": {
				"password": "some encrypted password"
			}
		},
		"networks": {
			"netA": {
				"default": ["dns", "gateway"],
				"ip": "ww.ww.ww.ww",
				"dns": [
					"xx.xx.xx.xx",
					"yy.yy.yy.yy"
				]
			},
			"netB": {
				"dns": [
					"zz.zz.zz.zz"
				]
			}
		},
		"mbus": "https://vcap:b00tstrap@0.0.0.0:6868",
		"ntp": [
			"0.north-america.pool.ntp.org",
			"1.north-america.pool.ntp.org"
		],
		"vm": {
			"name": "vm-abc-def"
		}
	}`
	settingsJson = strings.Replace(settingsJson, `"`, `\"`, -1)
	settingsJson = strings.Replace(settingsJson, "\n", "", -1)
	settingsJson = strings.Replace(settingsJson, "\t", "", -1)

	settingsJson = fmt.Sprintf(`{"settings": "%s"}`, settingsJson)

	expectedSettings = boshsettings.Settings{
		AgentId: "my-agent-id",
		Blobstore: boshsettings.Blobstore{
			Options: map[string]string{
				"bucket_name":       "george",
				"encryption_key":    "optional encryption key",
				"access_key_id":     "optional access key id",
				"secret_access_key": "optional secret access key",
			},
			Type: "s3",
		},
		Disks: boshsettings.Disks{
			Ephemeral:  "/dev/sdb",
			Persistent: map[string]string{"vol-xxxxxx": "/dev/sdf"},
			System:     "/dev/sda1",
		},
		Env: boshsettings.Env{
			Bosh: boshsettings.BoshEnv{
				Password: "some encrypted password",
			},
		},
		Networks: boshsettings.Networks{
			"netA": boshsettings.Network{
				Default: []string{"dns", "gateway"},
				Ip:      "ww.ww.ww.ww",
				Dns:     []string{"xx.xx.xx.xx", "yy.yy.yy.yy"},
			},
			"netB": boshsettings.Network{
				Dns: []string{"zz.zz.zz.zz"},
			},
		},
		Mbus: "https://vcap:b00tstrap@0.0.0.0:6868",
		Ntp: []string{
			"0.north-america.pool.ntp.org",
			"1.north-america.pool.ntp.org",
		},
		Vm: boshsettings.Vm{
			Name: "vm-abc-def",
		},
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, r.Method, "GET")
		assert.Equal(t, r.URL.Path, "/instances/123-456-789/settings")
		w.Write([]byte(settingsJson))
	})

	ts = httptest.NewServer(handler)

	registryUrl, err := url.Parse(ts.URL)
	assert.NoError(t, err)
	port = strings.Split(registryUrl.Host, ":")[1]

	return
}

func spinUpAwsMetadataServer(t *testing.T, userData string) (ts *httptest.Server) {
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
