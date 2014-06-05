package applyspec

import (
	"encoding/json"

	bosherr "bosh/errors"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
)

type concreteV1Service struct {
	fs           boshsys.FileSystem
	specFilePath string
}

func NewConcreteV1Service(fs boshsys.FileSystem, specFilePath string) concreteV1Service {
	return concreteV1Service{fs: fs, specFilePath: specFilePath}
}

func (s concreteV1Service) Get() (V1ApplySpec, error) {
	var spec V1ApplySpec

	if !s.fs.FileExists(s.specFilePath) {
		return spec, nil
	}

	contents, err := s.fs.ReadFile(s.specFilePath)
	if err != nil {
		return spec, bosherr.WrapError(err, "Reading json spec file")
	}

	err = json.Unmarshal([]byte(contents), &spec)
	if err != nil {
		return spec, bosherr.WrapError(err, "Unmarshalling json spec file")
	}

	return spec, nil
}

func (s concreteV1Service) Set(spec V1ApplySpec) error {
	specBytes, err := json.Marshal(spec)
	if err != nil {
		return bosherr.WrapError(err, "Marshalling apply spec")
	}

	err = s.fs.WriteFile(s.specFilePath, specBytes)
	if err != nil {
		return bosherr.WrapError(err, "Writing spec to disk")
	}

	return nil
}

func (s concreteV1Service) PopulateDynamicNetworks(spec V1ApplySpec, settings boshsettings.Settings) (V1ApplySpec, error) {
	for networkName, networkSpec := range spec.NetworkSpecs {
		if !networkSpec.IsDynamic() {
			continue
		}

		network, ok := settings.Networks[networkName]
		if !ok {
			return V1ApplySpec{}, bosherr.New("Network %s is not found in settings", networkName)
		}

		spec.NetworkSpecs[networkName] = networkSpec.PopulateIPInfo(
			network.IP,
			network.Netmask,
			network.Gateway,
		)
	}

	return spec, nil
}
