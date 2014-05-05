package infrastructure

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"strings"

	bosherr "bosh/errors"
)

type concreteMetadataService struct {
	metadataHost string
	resolver     dnsResolver
}

type userDataType struct {
	Registry struct {
		Endpoint string
	}
	Server struct {
		Name string // Name given by CPI e.g. vm-384sd4-r7re9e...
	}
	DNS struct {
		Nameserver []string
	}
}

func NewConcreteMetadataService(
	metadataHost string,
	resolver dnsResolver,
) concreteMetadataService {
	return concreteMetadataService{
		metadataHost: metadataHost,
		resolver:     resolver,
	}
}

func (ms concreteMetadataService) GetPublicKey() (string, error) {
	url := fmt.Sprintf("%s/latest/meta-data/public-keys/0/openssh-key", ms.metadataHost)
	resp, err := http.Get(url)
	if err != nil {
		return "", bosherr.WrapError(err, "Getting open ssh key")
	}

	defer resp.Body.Close()

	bytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", bosherr.WrapError(err, "Reading ssh key response body")
	}

	return string(bytes), nil
}

func (ms concreteMetadataService) GetInstanceID() (string, error) {
	url := fmt.Sprintf("%s/latest/meta-data/instance-id", ms.metadataHost)
	resp, err := http.Get(url)
	if err != nil {
		return "", bosherr.WrapError(err, "Getting instance id from url")
	}

	defer resp.Body.Close()

	bytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", bosherr.WrapError(err, "Reading instance id response body")
	}

	return string(bytes), nil
}

func (ms concreteMetadataService) GetServerName() (string, error) {
	userData, err := ms.getUserData()
	if err != nil {
		return "", bosherr.WrapError(err, "Getting user data")
	}

	serverName := userData.Server.Name

	if len(serverName) == 0 {
		return "", bosherr.New("Empty server name")
	}

	return serverName, nil
}

func (ms concreteMetadataService) GetRegistryEndpoint() (string, error) {
	userData, err := ms.getUserData()
	if err != nil {
		return "", bosherr.WrapError(err, "Getting user data")
	}

	endpoint := userData.Registry.Endpoint
	nameServers := userData.DNS.Nameserver

	if len(nameServers) > 0 {
		endpoint, err = ms.resolveRegistryEndpoint(endpoint, nameServers)
		if err != nil {
			return "", bosherr.WrapError(err, "Resolving registry endpoint")
		}
	}

	return endpoint, nil
}

func (ms concreteMetadataService) getUserData() (userDataType, error) {
	var userData userDataType

	userDataURL := fmt.Sprintf("%s/latest/user-data", ms.metadataHost)

	userDataResp, err := http.Get(userDataURL)
	if err != nil {
		return userData, bosherr.WrapError(err, "Getting user data from url")
	}

	defer userDataResp.Body.Close()

	userDataBytes, err := ioutil.ReadAll(userDataResp.Body)
	if err != nil {
		return userData, bosherr.WrapError(err, "Reading user data response body")
	}

	err = json.Unmarshal(userDataBytes, &userData)
	if err != nil {
		return userData, bosherr.WrapError(err, "Unmarshalling user data")
	}

	return userData, nil
}

func (ms concreteMetadataService) resolveRegistryEndpoint(namedEndpoint string, nameServers []string) (string, error) {
	registryURL, err := url.Parse(namedEndpoint)
	if err != nil {
		return "", bosherr.WrapError(err, "Parsing registry named endpoint")
	}

	registryHostAndPort := strings.Split(registryURL.Host, ":")
	registryIP, err := ms.resolver.LookupHost(nameServers, registryHostAndPort[0])
	if err != nil {
		return "", bosherr.WrapError(err, "Looking up registry")
	}

	if len(registryHostAndPort) == 2 {
		registryURL.Host = fmt.Sprintf("%s:%s", registryIP, registryHostAndPort[1])
	} else {
		registryURL.Host = registryIP
	}

	return registryURL.String(), nil
}
