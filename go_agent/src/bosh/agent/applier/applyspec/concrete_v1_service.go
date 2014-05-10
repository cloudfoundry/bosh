package applyspec

import (
	"encoding/json"

	bosherr "bosh/errors"
	boshsys "bosh/system"
)

type concreteV1Service struct {
	fs                     boshsys.FileSystem
	defaultNetworkDelegate DefaultNetworkDelegate
	specFilePath           string
}

func NewConcreteV1Service(
	fs boshsys.FileSystem,
	defaultNetworkDelegate DefaultNetworkDelegate,
	specFilePath string,
) concreteV1Service {
	return concreteV1Service{
		fs: fs,
		defaultNetworkDelegate: defaultNetworkDelegate,
		specFilePath:           specFilePath,
	}
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

func (s concreteV1Service) ResolveDynamicNetworks(spec V1ApplySpec) (V1ApplySpec, error) {
	var foundOneDynamicNetwork bool

	for networkName, networkSpec := range spec.NetworkSpecs {
		if !networkSpec.IsDynamic() {
			continue
		}

		// Currently proper support for multiple dynamic networks is not possible
		// because CPIs (e.g. AWS and OpenStack) do not include MAC address
		// for dynamic networks and that is the only way to reliably determine
		// network to interface to IP mapping
		if foundOneDynamicNetwork {
			return V1ApplySpec{}, bosherr.New("Multiple dynamic networks are not supported")
		}
		foundOneDynamicNetwork = true

		// Ideally this would be GetNetworkByMACAddress(mac string)
		network, err := s.defaultNetworkDelegate.GetDefaultNetwork()
		if err != nil {
			return V1ApplySpec{}, bosherr.WrapError(err, "Getting default network")
		}

		spec.NetworkSpecs[networkName] = networkSpec.PopulateIPInfo(
			network.IP,
			network.Netmask,
			network.Gateway,
		)
	}

	return spec, nil
}
