package platform

import (
	bosherror "bosh/errors"
	boshlog "bosh/logger"
	boshstats "bosh/platform/stats"
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
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

	p.platforms = map[string]Platform{
		"ubuntu": newUbuntuPlatform(sigarStatsCollector, fs, runner, dirProvider),
		"centos": newCentosPlatform(sigarStatsCollector, fs, runner, dirProvider),
		"dummy":  newDummyPlatform(sigarStatsCollector, fs, runner, dirProvider),
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
