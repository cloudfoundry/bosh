package platform

import (
	bosherror "bosh/errors"
	boshlog "bosh/logger"
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
	ubuntuDiskManager := boshdisk.NewUbuntuDiskManager(logger, runner, fs)
	centosDiskManager := boshdisk.NewCentosDiskManager(logger, runner, fs)

	p.platforms = map[string]Platform{
		"ubuntu": NewUbuntuPlatform(sigarStatsCollector, fs, runner, ubuntuDiskManager, dirProvider, 500*time.Millisecond, 10*time.Second, 3*time.Minute),
		"centos": NewCentosPlatform(sigarStatsCollector, fs, runner, centosDiskManager, dirProvider, 500*time.Millisecond, 10*time.Second, 3*time.Minute),
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
