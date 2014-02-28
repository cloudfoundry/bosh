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
	"time"
)

type dummyInfrastructure struct {
	fs                 boshsys.FileSystem
	dirProvider        boshdir.DirectoriesProvider
	platform           boshplatform.Platform
	devicePathResolver boshdevicepathresolver.DevicePathResolver
	diskWaitTimeout    time.Duration
}

func NewDummyInfrastructure(fs boshsys.FileSystem, dirProvider boshdir.DirectoriesProvider, platform boshplatform.Platform) (inf dummyInfrastructure) {
	inf.fs = fs
	inf.dirProvider = dirProvider
	inf.platform = platform

	inf.diskWaitTimeout = 1 * time.Millisecond
	inf.devicePathResolver = boshdevicepathresolver.NewDummyDevicePathResolver(inf.diskWaitTimeout, inf.platform.GetFs())
	inf.platform.SetDevicePathResolver(inf.devicePathResolver)

	return
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
