package infrastructure

import (
	bosherr "bosh/errors"
	boshdevicepathresolver "bosh/infrastructure/device_path_resolver"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
	"encoding/json"
	"path/filepath"
)

type dummyInfrastructure struct {
	fs                 boshsys.FileSystem
	dirProvider        boshdir.DirectoriesProvider
	platform           boshplatform.Platform
	devicePathResolver boshdevicepathresolver.DevicePathResolver
}

func NewDummyInfrastructure(fs boshsys.FileSystem, dirProvider boshdir.DirectoriesProvider,
	platform boshplatform.Platform,
	devicePathResolver boshdevicepathresolver.DevicePathResolver) (inf dummyInfrastructure) {
	inf.fs = fs
	inf.dirProvider = dirProvider
	inf.platform = platform
	inf.devicePathResolver = devicePathResolver

	return
}

func (inf dummyInfrastructure) GetDevicePathResolver() boshdevicepathresolver.DevicePathResolver {
	return inf.devicePathResolver
}

func (inf dummyInfrastructure) SetupSsh(username string) (err error) {
	return
}

func (inf dummyInfrastructure) GetSettings() (settings boshsettings.Settings, err error) {
	settingsPath := filepath.Join(inf.dirProvider.BaseDir(), "bosh", "settings.json")
	contents, err := inf.fs.ReadFile(settingsPath)
	if err != nil {
		err = bosherr.WrapError(err, "Read settings file")
		return
	}

	err = json.Unmarshal([]byte(contents), &settings)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshal json settings")
		return
	}

	return
}

func (inf dummyInfrastructure) SetupNetworking(networks boshsettings.Networks) (err error) {
	return
}

func (inf dummyInfrastructure) GetEphemeralDiskPath(devicePath string) (realPath string, found bool) {
	return inf.platform.NormalizeDiskPath(devicePath)
}

func (inf dummyInfrastructure) MountPersistentDisk(volumeId string, mountPoint string) (err error) {
	return
}
