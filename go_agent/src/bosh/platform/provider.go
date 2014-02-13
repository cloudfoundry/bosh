package platform

import (
	bosherror "bosh/errors"
	boshlog "bosh/logger"
	boshcdrom "bosh/platform/cdrom"
	boshudev "bosh/platform/cdrom/udevdevice"
	boshcd "bosh/platform/cdutil"
	boshdisk "bosh/platform/disk"
	boshstats "bosh/platform/stats"
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
	"time"
)

type provider struct {
	platforms map[string]Platform
}

// There is a reason the runner is not injected.
// Other entities should not use a runner, they should go through the platform
func NewProvider(logger boshlog.Logger, dirProvider boshdirs.DirectoriesProvider) (p provider) {
	runner := boshsys.NewExecCmdRunner(logger)
	fs := boshsys.NewOsFileSystem(logger, runner)
	sigarStatsCollector := boshstats.NewSigarStatsCollector()
	linuxDiskManager := boshdisk.NewLinuxDiskManager(logger, runner, fs)

	udev := boshudev.NewConcreteUdevDevice(runner)
	linuxCdrom := boshcdrom.NewLinuxCdrom("/dev/sr0", udev, runner)
	linuxCdutil := boshcd.NewCdUtil(dirProvider.SettingsDir(), fs, linuxCdrom)

	p.platforms = map[string]Platform{
		"ubuntu": NewUbuntuPlatform(sigarStatsCollector, fs, runner, linuxDiskManager, dirProvider, linuxCdutil, 10*time.Second, 3*time.Minute),
		"centos": NewCentosPlatform(sigarStatsCollector, fs, runner, linuxDiskManager, dirProvider, linuxCdutil, 10*time.Second, 3*time.Minute),
		"dummy":  NewDummyPlatform(sigarStatsCollector, fs, runner, dirProvider),
	}
	return
}

func (p provider) Get(name string) (plat Platform, err error) {
	plat, found := p.platforms[name]

	if !found {
		err = bosherror.New("Platform %s could not be found", name)
	}
	return
}
