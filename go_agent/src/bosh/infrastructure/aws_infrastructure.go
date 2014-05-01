package infrastructure

import (
	"fmt"

	bosherr "bosh/errors"
	boshdpresolv "bosh/infrastructure/devicepathresolver"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type awsInfrastructure struct {
	metadataService    MetadataService
	registry           Registry
	platform           boshplatform.Platform
	devicePathResolver boshdpresolv.DevicePathResolver
}

func NewAwsInfrastructure(
	metadataService MetadataService,
	registry Registry,
	platform boshplatform.Platform,
	devicePathResolver boshdpresolv.DevicePathResolver,
) (inf awsInfrastructure) {
	inf.metadataService = metadataService
	inf.registry = registry
	inf.platform = platform
	inf.devicePathResolver = devicePathResolver
	return
}

func (inf awsInfrastructure) GetDevicePathResolver() boshdpresolv.DevicePathResolver {
	return inf.devicePathResolver
}

func (inf awsInfrastructure) SetupSsh(username string) error {
	publicKey, err := inf.metadataService.GetPublicKey()
	if err != nil {
		return bosherr.WrapError(err, "Error getting public key")
	}

	return inf.platform.SetupSsh(publicKey, username)
}

func (inf awsInfrastructure) GetSettings() (boshsettings.Settings, error) {
	var settings boshsettings.Settings

	instanceID, err := inf.metadataService.GetInstanceID()
	if err != nil {
		return settings, bosherr.WrapError(err, "Getting instance id")
	}

	registryEndpoint, err := inf.metadataService.GetRegistryEndpoint()
	if err != nil {
		return settings, bosherr.WrapError(err, "Getting registry endpoint")
	}

	settingsURL := fmt.Sprintf("%s/instances/%s/settings", registryEndpoint, instanceID)
	settings, err = inf.registry.GetSettingsAtURL(settingsURL)
	if err != nil {
		return settings, bosherr.WrapError(err, "Getting settings from url")
	}

	return settings, nil
}

func (inf awsInfrastructure) SetupNetworking(networks boshsettings.Networks) (err error) {
	return inf.platform.SetupDhcp(networks)
}

func (inf awsInfrastructure) GetEphemeralDiskPath(devicePath string) (realPath string, found bool) {
	return inf.platform.NormalizeDiskPath(devicePath)
}
