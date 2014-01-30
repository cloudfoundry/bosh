package infrastructure

import (
	bosherr "bosh/errors"
	boshsettings "bosh/settings"
	boshsys "bosh/system"
	"encoding/json"
	"path"
	"path/filepath"
	"time"
)

type vsphereInfrastructure struct {
	cdromDelegate               CDROMDelegate
	persistentDiskRetryInterval time.Duration
	persistentDiskMaxRetries    int
}

func newVsphereInfrastructure(delegate CDROMDelegate) (inf vsphereInfrastructure) {
	inf.cdromDelegate = delegate
	inf.persistentDiskRetryInterval = 1 * time.Second
	inf.persistentDiskMaxRetries = 30
	return
}

func (inf vsphereInfrastructure) SetupSsh(delegate SshSetupDelegate, username string) (err error) {
	return
}

func (inf vsphereInfrastructure) GetSettings() (settings boshsettings.Settings, err error) {
	contents, err := inf.cdromDelegate.GetFileContentsFromCDROM("env")
	if err != nil {
		err = bosherr.WrapError(err, "Reading contents from CDROM")
		return
	}

	err = json.Unmarshal(contents, &settings)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling settings from CDROM")
	}

	return
}

func (inf vsphereInfrastructure) SetupNetworking(delegate NetworkingDelegate, networks boshsettings.Networks) (err error) {
	return delegate.SetupManualNetworking(networks)
}

func (inf vsphereInfrastructure) GetPersistentDiskPath(cid string, fs boshsys.FileSystem, scsiDelegate ScsiDelegate) (realPath string, found bool) {
	scsiDelegate.RescanScsiBus()

	devicePath := "/sys/bus/scsi/devices/2:0:" + cid + ":0/block/*"

	fileMatches, _ := fs.Glob(devicePath)

	for i := 0; len(fileMatches) == 0 && i < inf.persistentDiskMaxRetries; i++ {
		time.Sleep(inf.persistentDiskRetryInterval)
		fileMatches, _ = fs.Glob(devicePath)
	}

	if len(fileMatches) == 0 {
		return
	}

	blockName := path.Base(fileMatches[0])
	realPath = filepath.Join("/dev", blockName)
	found = true

	return
}

func (inf vsphereInfrastructure) GetEphemeralDiskPath(_ string, fs boshsys.FileSystem) (realPath string, found bool) {
	path := "/dev/sdb"
	if fs.FileExists(path) {
		realPath = path
		found = true
	}
	return
}
