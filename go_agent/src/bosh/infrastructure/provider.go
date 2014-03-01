package infrastructure

import (
	bosherr "bosh/errors"
	boshdevicepathresolver "bosh/infrastructure/device_path_resolver"
	boshlog "bosh/logger"
	boshplatform "bosh/platform"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
	"time"
)

type Provider struct {
	infrastructures map[string]Infrastructure
}

func NewProvider(logger boshlog.Logger, platform boshplatform.Platform) (p Provider) {
	digDnsResolver := NewDigDnsResolver(logger)

	p.infrastructures = map[string]Infrastructure{
		"aws":     p.createAwsInfrastructure("http://169.254.169.254", digDnsResolver, platform),
		"vsphere": p.createVsphereInfrastructure(platform),
		"dummy":   p.createDummyInfrastructure(platform.GetFs(), platform.GetDirProvider(), platform),
	}
	return
}

func (p Provider) Get(name string) (inf Infrastructure, err error) {
	inf, found := p.infrastructures[name]

	if !found {
		err = bosherr.New("Infrastructure %s could not be found", name)
	}
	return
}

func (p Provider) createVsphereInfrastructure(platform boshplatform.Platform) (inf Infrastructure) {

	devicePathResolver := boshdevicepathresolver.NewVsphereDevicePathResolver(500*time.Millisecond, platform.GetFs())
	inf = NewVsphereInfrastructure(platform, devicePathResolver)
	return
}

func (p Provider) createAwsInfrastructure(metadataHost string, resolver dnsResolver,
	platform boshplatform.Platform) (inf Infrastructure) {

	devicePathResolver := boshdevicepathresolver.NewAwsDevicePathResolver(500*time.Millisecond, platform.GetFs())
	inf = NewAwsInfrastructure(metadataHost, resolver, platform, devicePathResolver)
	return
}

func (p Provider) createDummyInfrastructure(fs boshsys.FileSystem, dirProvider boshdir.DirectoriesProvider,
	platform boshplatform.Platform) (inf Infrastructure) {
	devicePathResolver := boshdevicepathresolver.NewDummyDevicePathResolver(1*time.Millisecond, platform.GetFs())
	inf = NewDummyInfrastructure(fs, dirProvider, platform, devicePathResolver)
	return
}
