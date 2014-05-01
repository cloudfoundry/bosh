package infrastructure

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"strings"

	bosherr "bosh/errors"
	boshdpresolv "bosh/infrastructure/devicepathresolver"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type awsInfrastructure struct {
	metadataHost       string
	metadataService    MetadataService
	registry           Registry
	resolver           dnsResolver
	platform           boshplatform.Platform
	devicePathResolver boshdpresolv.DevicePathResolver
}

func NewAwsInfrastructure(
	metadataHost string,
	metadataService MetadataService,
	registry Registry,
	resolver dnsResolver,
	platform boshplatform.Platform,
	devicePathResolver boshdpresolv.DevicePathResolver,
) (inf awsInfrastructure) {
	inf.metadataHost = metadataHost
	inf.metadataService = metadataService
	inf.registry = registry
	inf.resolver = resolver
	inf.platform = platform
	inf.devicePathResolver = devicePathResolver
	return
}

func (inf awsInfrastructure) GetDevicePathResolver() boshdpresolv.DevicePathResolver {
	return inf.devicePathResolver
}

func (inf awsInfrastructure) SetupSsh(username string) (err error) {
	publicKey, err := inf.metadataService.GetPublicKey()
	if err != nil {
		err = bosherr.WrapError(err, "Error getting public key")
		return
	}

	err = inf.platform.SetupSsh(publicKey, username)
	return
}

func (inf awsInfrastructure) GetSettings() (settings boshsettings.Settings, err error) {
	instanceID, err := inf.getInstanceID()
	if err != nil {
		err = bosherr.WrapError(err, "Getting instance id")
		return
	}

	registryEndpoint, err := inf.getRegistryEndpoint()
	if err != nil {
		err = bosherr.WrapError(err, "Getting registry endpoint")
		return
	}

	settingsURL := fmt.Sprintf("%s/instances/%s/settings", registryEndpoint, instanceID)
	settings, err = inf.registry.GetSettingsAtURL(settingsURL)
	if err != nil {
		err = bosherr.WrapError(err, "Getting settings from url")
	}
	return
}

func (inf awsInfrastructure) SetupNetworking(networks boshsettings.Networks) (err error) {
	return inf.platform.SetupDhcp(networks)
}

func (inf awsInfrastructure) GetEphemeralDiskPath(devicePath string) (realPath string, found bool) {
	return inf.platform.NormalizeDiskPath(devicePath)
}

func (inf awsInfrastructure) getInstanceID() (instanceID string, err error) {
	instanceIDURL := fmt.Sprintf("%s/latest/meta-data/instance-id", inf.metadataHost)
	instanceIDResp, err := http.Get(instanceIDURL)
	if err != nil {
		err = bosherr.WrapError(err, "Getting instance id from url")
		return
	}

	defer instanceIDResp.Body.Close()

	instanceIDBytes, err := ioutil.ReadAll(instanceIDResp.Body)
	if err != nil {
		err = bosherr.WrapError(err, "Reading instance id response body")
		return
	}

	instanceID = string(instanceIDBytes)
	return
}

func (inf awsInfrastructure) getRegistryEndpoint() (endpoint string, err error) {
	userData, err := inf.getUserData()
	if err != nil {
		err = bosherr.WrapError(err, "Getting user data")
		return
	}

	endpoint = userData.Registry.Endpoint
	nameServers := userData.DNS.Nameserver

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
	DNS struct {
		Nameserver []string
	}
}

func (inf awsInfrastructure) getUserData() (userData userDataType, err error) {
	userDataURL := fmt.Sprintf("%s/latest/user-data", inf.metadataHost)

	userDataResp, err := http.Get(userDataURL)
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
	registryURL, err := url.Parse(namedEndpoint)
	if err != nil {
		err = bosherr.WrapError(err, "Parsing registry named endpoint")
		return
	}

	registryHostAndPort := strings.Split(registryURL.Host, ":")
	registryIP, err := inf.resolver.LookupHost(nameServers, registryHostAndPort[0])
	if err != nil {
		err = bosherr.WrapError(err, "Looking up registry")
		return
	}

	registryURL.Host = fmt.Sprintf("%s:%s", registryIP, registryHostAndPort[1])
	resolvedEndpoint = registryURL.String()
	return
}
