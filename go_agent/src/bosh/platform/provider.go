package platform

import (
	bosherror "bosh/errors"
	boshlog "bosh/logger"
	boshdisk "bosh/platform/disk"
	boshstats "bosh/platform/stats"
	boshsys "bosh/system"
)

type provider struct {
	platforms map[string]Platform
}

func NewProvider(logger boshlog.Logger) (p provider) {
	fs := boshsys.NewOsFileSystem()

	// There is a reason the runner is not injected.
	// Other entities should not use a runner, they should go through the platform
	runner := boshsys.NewExecCmdRunner(logger)
	sigarStatsCollector := boshstats.NewSigarStatsCollector()
	ubuntuDiskManager := boshdisk.NewUbuntuDiskManager(logger, runner, fs)
	compressor := boshdisk.NewCompressor(runner, fs)

	p.platforms = map[string]Platform{
		"ubuntu": newUbuntuPlatform(sigarStatsCollector, fs, runner, ubuntuDiskManager, compressor),
		"dummy":  newDummyPlatform(),
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
