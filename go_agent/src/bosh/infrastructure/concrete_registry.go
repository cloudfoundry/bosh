package infrastructure

import (
	"encoding/json"
	"io/ioutil"
	"net/http"

	bosherr "bosh/errors"
	boshsettings "bosh/settings"
)

type concreteRegistry struct{}

func NewConcreteRegistry() concreteRegistry {
	return concreteRegistry{}
}

type settingsWrapperType struct {
	Settings string
}

func (r concreteRegistry) GetSettingsAtURL(settingsURL string) (boshsettings.Settings, error) {
	var settings boshsettings.Settings

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
