package platform

import (
	bosherr "bosh/errors"
	boshcd "bosh/platform/cdutil"
	boshcmd "bosh/platform/commands"
	boshstats "bosh/platform/stats"
	boshvitals "bosh/platform/vitals"
	boshdir "bosh/settings/directories"
	boshdirs "bosh/settings/directories"
	boshsys "bosh/system"
)

type linux struct {
	fs            boshsys.FileSystem
	cmdRunner     boshsys.CmdRunner
	collector     boshstats.StatsCollector
	compressor    boshcmd.Compressor
	copier        boshcmd.Copier
	dirProvider   boshdirs.DirectoriesProvider
	vitalsService boshvitals.Service
	cdutil        boshcd.CdUtil
}

func NewLinuxPlatform(
	fs boshsys.FileSystem,
	cmdRunner boshsys.CmdRunner,
	collector boshstats.StatsCollector,
	compressor boshcmd.Compressor,
	copier boshcmd.Copier,
	dirProvider boshdirs.DirectoriesProvider,
	vitalsService boshvitals.Service,
	cdutil boshcd.CdUtil,
) (platform linux) {
	platform = linux{
		fs:            fs,
		cmdRunner:     cmdRunner,
		collector:     collector,
		compressor:    compressor,
		copier:        copier,
		dirProvider:   dirProvider,
		vitalsService: vitalsService,
		cdutil:        cdutil,
	}
	return
}

func (p linux) GetFs() (fs boshsys.FileSystem) {
	return p.fs
}

func (p linux) GetRunner() (runner boshsys.CmdRunner) {
	return p.cmdRunner
}

func (p linux) GetStatsCollector() (statsCollector boshstats.StatsCollector) {
	return p.collector
}

func (p linux) GetCompressor() (runner boshcmd.Compressor) {
	return p.compressor
}

func (p linux) GetCopier() (runner boshcmd.Copier) {
	return p.copier
}

func (p linux) GetDirProvider() (dirProvider boshdir.DirectoriesProvider) {
	return p.dirProvider
}

func (p linux) GetVitalsService() (service boshvitals.Service) {
	return p.vitalsService
}

func (p linux) GetFileContentsFromCDROM(fileName string) (contents []byte, err error) {
	return p.cdutil.GetFileContents(fileName)
}

func (p linux) SetupRuntimeConfiguration() (err error) {
	_, _, err = p.cmdRunner.RunCommand("bosh-agent-rc")
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to bosh-agent-rc")
	}
	return
}
