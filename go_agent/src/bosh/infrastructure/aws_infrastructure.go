package infrastructure

import (
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

func newAwsInfrastructure(metadataHost string, resolver dnsResolver) (infrastructure Infrastructure) {
	return awsInfrastructure{
		metadataHost: metadataHost,
		resolver:     resolver,
	}
}

func (inf awsInfrastructure) GetPublicKey() (publicKey string, err error) {
	url := fmt.Sprintf("%s/latest/meta-data/public-keys/0/openssh-key", inf.metadataHost)

	resp, err := http.Get(url)
	if err != nil {
		return
	}
	defer resp.Body.Close()

	keyBytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return
	}

	publicKey = string(keyBytes)
	return
}

func (inf awsInfrastructure) GetSettings() (settings Settings, err error) {
	instanceId, err := inf.getInstanceId()
	if err != nil {
		return
	}

	registryEndpoint, err := inf.getRegistryEndpoint()
	if err != nil {
		return
	}

	settingsUrl := fmt.Sprintf("%s/instances/%s/settings", registryEndpoint, instanceId)

	settingsResp, err := http.Get(settingsUrl)
	if err != nil {
		return
	}
	defer settingsResp.Body.Close()

	settingsBytes, err := ioutil.ReadAll(settingsResp.Body)
	if err != nil {
		return
	}

	err = json.Unmarshal(settingsBytes, &settings)
	return
}

func (inf awsInfrastructure) getInstanceId() (instanceId string, err error) {
	instanceIdUrl := fmt.Sprintf("%s/latest/meta-data/instance-id", inf.metadataHost)
	instanceIdResp, err := http.Get(instanceIdUrl)
	if err != nil {
		return
	}
	defer instanceIdResp.Body.Close()

	instanceIdBytes, err := ioutil.ReadAll(instanceIdResp.Body)
	if err != nil {
		return
	}

	instanceId = string(instanceIdBytes)
	return
}

func (inf awsInfrastructure) getRegistryEndpoint() (endpoint string, err error) {
	userData, err := inf.getUserData()
	if err != nil {
		return
	}

	endpoint = userData.Registry.Endpoint
	nameServers := userData.Dns.Nameserver

	if len(nameServers) > 0 {
		endpoint, err = inf.resolveRegistryEndpoint(endpoint, nameServers)
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
		return
	}
	defer userDataResp.Body.Close()

	userDataBytes, err := ioutil.ReadAll(userDataResp.Body)
	if err != nil {
		return
	}

	err = json.Unmarshal(userDataBytes, &userData)
	return
}

func (inf awsInfrastructure) resolveRegistryEndpoint(namedEndpoint string, nameServers []string) (resolvedEndpoint string, err error) {
	registryUrl, err := url.Parse(namedEndpoint)
	if err != nil {
		return
	}

	registryHostAndPort := strings.Split(registryUrl.Host, ":")
	registryIp, err := inf.resolver.LookupHost(nameServers, registryHostAndPort[0])
	if err != nil {
		return
	}

	registryUrl.Host = fmt.Sprintf("%s:%s", registryIp, registryHostAndPort[1])
	resolvedEndpoint = registryUrl.String()
	return
}
