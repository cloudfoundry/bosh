package infrastructure

import (
	bosherr "bosh/errors"
	boshsettings "bosh/settings"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"strings"
)

type awsInfrastructure struct {
	metadataHost string
	resolver     dnsResolver
}

func newAwsInfrastructure(metadataHost string, resolver dnsResolver) (infrastructure awsInfrastructure) {
	infrastructure.metadataHost = metadataHost
	infrastructure.resolver = resolver
	return
}

func (inf awsInfrastructure) SetupSsh(delegate SshSetupDelegate, username string) (err error) {
	publicKey, err := inf.getPublicKey()
	if err != nil {
		err = bosherr.WrapError(err, "Error getting public key")
		return
	}

	err = delegate.SetupSsh(publicKey, username)
	return
}

func (inf awsInfrastructure) getPublicKey() (publicKey string, err error) {
	url := fmt.Sprintf("%s/latest/meta-data/public-keys/0/openssh-key", inf.metadataHost)

	resp, err := http.Get(url)
	if err != nil {
		err = bosherr.WrapError(err, "Getting open ssh key")
		return
	}
	defer resp.Body.Close()

	keyBytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		err = bosherr.WrapError(err, "Reading ssh key response body")
		return
	}

	publicKey = string(keyBytes)
	return
}

func (inf awsInfrastructure) GetSettings() (settings boshsettings.Settings, err error) {
	instanceId, err := inf.getInstanceId()
	if err != nil {
		err = bosherr.WrapError(err, "Getting instance id")
		return
	}

	registryEndpoint, err := inf.getRegistryEndpoint()
	if err != nil {
		err = bosherr.WrapError(err, "Getting registry endpoint")
		return
	}

	settingsUrl := fmt.Sprintf("%s/instances/%s/settings", registryEndpoint, instanceId)
	settings, err = inf.getSettingsAtUrl(settingsUrl)
	if err != nil {
		err = bosherr.WrapError(err, "Getting settings from url")
	}
	return
}

func (inf awsInfrastructure) SetupNetworking(delegate NetworkingDelegate, networks boshsettings.Networks) (err error) {
	return delegate.SetupDhcp(networks)
}

func (inf awsInfrastructure) getInstanceId() (instanceId string, err error) {
	instanceIdUrl := fmt.Sprintf("%s/latest/meta-data/instance-id", inf.metadataHost)
	instanceIdResp, err := http.Get(instanceIdUrl)
	if err != nil {
		err = bosherr.WrapError(err, "Getting instance id from url")
		return
	}
	defer instanceIdResp.Body.Close()

	instanceIdBytes, err := ioutil.ReadAll(instanceIdResp.Body)
	if err != nil {
		err = bosherr.WrapError(err, "Reading instance id response body")
		return
	}

	instanceId = string(instanceIdBytes)
	return
}

func (inf awsInfrastructure) getRegistryEndpoint() (endpoint string, err error) {
	userData, err := inf.getUserData()
	if err != nil {
		err = bosherr.WrapError(err, "Getting user data")
		return
	}

	endpoint = userData.Registry.Endpoint
	nameServers := userData.Dns.Nameserver

	if len(nameServers) > 0 {
		endpoint, err = inf.resolveRegistryEndpoint(endpoint, nameServers)
		if err != nil {
			err = bosherr.WrapError(err, "Resolving registry endpoint")
			return
		}
	}
	return
}

type userDataType struct {
	Registry struct {
		Endpoint string
	}
	Dns struct {
		Nameserver []string
	}
}

func (inf awsInfrastructure) getUserData() (userData userDataType, err error) {
	userDataUrl := fmt.Sprintf("%s/latest/user-data", inf.metadataHost)

	userDataResp, err := http.Get(userDataUrl)
	if err != nil {
		err = bosherr.WrapError(err, "Getting user data from url")
		return
	}
	defer userDataResp.Body.Close()

	userDataBytes, err := ioutil.ReadAll(userDataResp.Body)
	if err != nil {
		err = bosherr.WrapError(err, "Reading user data response body")
		return
	}

	err = json.Unmarshal(userDataBytes, &userData)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling user data")
		return
	}
	return
}

func (inf awsInfrastructure) resolveRegistryEndpoint(namedEndpoint string, nameServers []string) (resolvedEndpoint string, err error) {
	registryUrl, err := url.Parse(namedEndpoint)
	if err != nil {
		err = bosherr.WrapError(err, "Parsing registry named endpoint")
		return
	}

	registryHostAndPort := strings.Split(registryUrl.Host, ":")
	registryIp, err := inf.resolver.LookupHost(nameServers, registryHostAndPort[0])
	if err != nil {
		err = bosherr.WrapError(err, "Looking up registry")
		return
	}

	registryUrl.Host = fmt.Sprintf("%s:%s", registryIp, registryHostAndPort[1])
	resolvedEndpoint = registryUrl.String()
	return
}

type settingsWrapperType struct {
	Settings string
}

func (inf awsInfrastructure) getSettingsAtUrl(settingsUrl string) (settings boshsettings.Settings, err error) {
	wrapperResponse, err := http.Get(settingsUrl)
	if err != nil {
		err = bosherr.WrapError(err, "Getting settings from url")
		return
	}
	defer wrapperResponse.Body.Close()

	wrapperBytes, err := ioutil.ReadAll(wrapperResponse.Body)
	if err != nil {
		err = bosherr.WrapError(err, "Reading settings response body")
		return
	}

	wrapper := new(settingsWrapperType)
	err = json.Unmarshal(wrapperBytes, wrapper)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling settings wrapper")
		return
	}

	err = json.Unmarshal([]byte(wrapper.Settings), &settings)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling wrapped settings")
	}
	return
}
