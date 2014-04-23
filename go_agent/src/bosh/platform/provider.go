package platform

import (
	"time"

	bosherror "bosh/errors"
	boshlog "bosh/logger"
	boshcdrom "bosh/platform/cdrom"
	boshudev "bosh/platform/cdrom/udevdevice"
	boshcd "bosh/platform/cdutil"
	boshcmd "bosh/platform/commands"
	boshdisk "bosh/platform/disk"
	boshnet "bosh/platform/net"
	boshstats "bosh/platform/stats"
	boshvitals "bosh/platform/vitals"
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
)

type provider struct {
	platforms map[string]Platform
}

type ProviderOptions struct {
	Linux LinuxOptions
}

func NewProvider(logger boshlog.Logger, dirProvider boshdirs.DirectoriesProvider, options ProviderOptions) (p provider) {
	runner := boshsys.NewExecCmdRunner(logger)
	fs := boshsys.NewOsFileSystem(logger)
	sigarCollector := boshstats.NewSigarStatsCollector()
	linuxDiskManager := boshdisk.NewLinuxDiskManager(logger, runner, fs)

	udev := boshudev.NewConcreteUdevDevice(runner)
	linuxCdrom := boshcdrom.NewLinuxCdrom("/dev/sr0", udev, runner)
	linuxCdutil := boshcd.NewCdUtil(dirProvider.SettingsDir(), fs, linuxCdrom)

	compressor := boshcmd.NewTarballCompressor(runner, fs)
	copier := boshcmd.NewCpCopier(runner, fs)
	vitalsService := boshvitals.NewService(sigarCollector, dirProvider)

	centosNetManager := boshnet.NewCentosNetManager(fs, runner, 10*time.Second)
	ubuntuNetManager := boshnet.NewUbuntuNetManager(fs, runner, 10*time.Second)

	centos := NewLinuxPlatform(
		fs,
		runner,
		sigarCollector,
		compressor,
		copier,
		dirProvider,
		vitalsService,
		linuxCdutil,
		linuxDiskManager,
		centosNetManager,
		500*time.Millisecond,
		options.Linux,
		logger,
	)

	ubuntu := NewLinuxPlatform(
		fs,
		runner,
		sigarCollector,
		compressor,
		copier,
		dirProvider,
		vitalsService,
		linuxCdutil,
		linuxDiskManager,
		ubuntuNetManager,
		500*time.Millisecond,
		options.Linux,
		logger,
	)

	p.platforms = map[string]Platform{
		"ubuntu": ubuntu,
		"centos": centos,
		"dummy":  NewDummyPlatform(sigarCollector, fs, runner, dirProvider, linuxDiskManager),
	}
	return
}

func (p provider) Get(name string) (Platform, error) {
	plat, found := p.platforms[name]
	if !found {
		return nil, bosherror.New("Platform %s could not be found", name)
	}
	return plat, nil
}
