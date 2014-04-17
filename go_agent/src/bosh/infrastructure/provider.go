package infrastructure

import (
	"time"

	bosherr "bosh/errors"
	boshdpresolv "bosh/infrastructure/devicepathresolver"
	boshlog "bosh/logger"
	boshplatform "bosh/platform"
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
)

type Provider struct {
	infrastructures map[string]Infrastructure
}

func NewProvider(logger boshlog.Logger, platform boshplatform.Platform) (p Provider) {
	digDNSResolver := NewDigDNSResolver(logger)
	p.infrastructures = map[string]Infrastructure{
		"aws":     p.createAwsInfrastructure("http://169.254.169.254", digDNSResolver, platform),
		"dummy":   p.createDummyInfrastructure(platform.GetFs(), platform.GetDirProvider(), platform),
		"vsphere": p.createVsphereInfrastructure(platform, logger),
	}
	return
}

func (p Provider) Get(name string) (Infrastructure, error) {
	inf, found := p.infrastructures[name]
	if !found {
		return nil, bosherr.New("Infrastructure %s could not be found", name)
	}
	return inf, nil
}

func (p Provider) createVsphereInfrastructure(platform boshplatform.Platform, logger boshlog.Logger) Infrastructure {
	devicePathResolver := boshdpresolv.NewVsphereDevicePathResolver(500*time.Millisecond, platform.GetFs())
	return NewVsphereInfrastructure(platform, devicePathResolver, logger)
}

func (p Provider) createAwsInfrastructure(
	metadataHost string,
	resolver dnsResolver,
	platform boshplatform.Platform,
) Infrastructure {
	devicePathResolver := boshdpresolv.NewAwsDevicePathResolver(500*time.Millisecond, platform.GetFs())
	return NewAwsInfrastructure(metadataHost, resolver, platform, devicePathResolver)
}

func (p Provider) createDummyInfrastructure(
	fs boshsys.FileSystem,
	dirProvider boshdir.DirectoriesProvider,
	platform boshplatform.Platform,
) Infrastructure {
	devicePathResolver := boshdpresolv.NewDummyDevicePathResolver(1*time.Millisecond, platform.GetFs())
	return NewDummyInfrastructure(fs, dirProvider, platform, devicePathResolver)
}
