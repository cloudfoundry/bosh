package platform

import (
	bosherror "bosh/errors"
	boshdisk "bosh/platform/disk"
	boshstats "bosh/platform/stats"
	boshsys "bosh/system"
)

type provider struct {
	platforms map[string]Platform
}

func NewProvider(fs boshsys.FileSystem) (p provider) {
	// There is a reason the runner is not injected.
	// Other entities should not use a runner, they should go through the platform
	runner := boshsys.ExecCmdRunner{}

	ubuntuDiskManager := boshdisk.NewUbuntuDiskManager(runner, fs)
	sigarStatsCollector := boshstats.NewSigarStatsCollector()

	p.platforms = map[string]Platform{
		"ubuntu": newUbuntuPlatform(sigarStatsCollector, fs, runner, ubuntuDiskManager),
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
