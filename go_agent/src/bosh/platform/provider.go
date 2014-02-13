package platform

import (
	bosherror "bosh/errors"
	boshlog "bosh/logger"
	boshcdrom "bosh/platform/cdrom"
	boshudev "bosh/platform/cdrom/udevdevice"
	boshcd "bosh/platform/cdutil"
	boshcmd "bosh/platform/commands"
	boshdisk "bosh/platform/disk"
	boshstats "bosh/platform/stats"
	boshvitals "bosh/platform/vitals"
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
	sigarCollector := boshstats.NewSigarStatsCollector()
	linuxDiskManager := boshdisk.NewLinuxDiskManager(logger, runner, fs)

	udev := boshudev.NewConcreteUdevDevice(runner)
	linuxCdrom := boshcdrom.NewLinuxCdrom("/dev/sr0", udev, runner)
	linuxCdutil := boshcd.NewCdUtil(dirProvider.SettingsDir(), fs, linuxCdrom)

	compressor := boshcmd.NewTarballCompressor(runner, fs)
	copier := boshcmd.NewCpCopier(runner, fs)
	vitalsService := boshvitals.NewService(sigarCollector, dirProvider)

	linux := NewLinuxPlatform(
		fs,
		runner,
		sigarCollector,
		compressor,
		copier,
		dirProvider,
		vitalsService,
		linuxCdutil,
		linuxDiskManager,
		3*time.Minute,
	)

	p.platforms = map[string]Platform{
		"ubuntu": NewUbuntuPlatform(
			linux,
			10*time.Second,
		),
		"centos": NewCentosPlatform(
			linux,
			10*time.Second,
		),
		"dummy": NewDummyPlatform(sigarCollector, fs, runner, dirProvider),
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
