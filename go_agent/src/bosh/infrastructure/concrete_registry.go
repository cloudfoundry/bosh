package infrastructure

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"

	bosherr "bosh/errors"
	boshsettings "bosh/settings"
)

type concreteRegistry struct {
	metadataService MetadataService
}

func NewConcreteRegistry(metadataService MetadataService) concreteRegistry {
	return concreteRegistry{metadataService: metadataService}
}

type settingsWrapperType struct {
	Settings string
}

func (r concreteRegistry) GetSettings() (boshsettings.Settings, error) {
	var settings boshsettings.Settings

	instanceID, err := r.metadataService.GetInstanceID()
	if err != nil {
		return settings, bosherr.WrapError(err, "Getting instance id")
	}

	registryEndpoint, err := r.metadataService.GetRegistryEndpoint()
	if err != nil {
		return settings, bosherr.WrapError(err, "Getting registry endpoint")
	}

	settingsURL := fmt.Sprintf("%s/instances/%s/settings", registryEndpoint, instanceID)
	wrapperResponse, err := http.Get(settingsURL)
	if err != nil {
		return settings, bosherr.WrapError(err, "Getting settings from url")
	}

	defer wrapperResponse.Body.Close()

	wrapperBytes, err := ioutil.ReadAll(wrapperResponse.Body)
	if err != nil {
		return settings, bosherr.WrapError(err, "Reading settings response body")
	}

	var wrapper settingsWrapperType
	err = json.Unmarshal(wrapperBytes, &wrapper)
	if err != nil {
		return settings, bosherr.WrapError(err, "Unmarshalling settings wrapper")
	}

	err = json.Unmarshal([]byte(wrapper.Settings), &settings)
	if err != nil {
		return settings, bosherr.WrapError(err, "Unmarshalling wrapped settings")
	}

	return settings, nil
}
