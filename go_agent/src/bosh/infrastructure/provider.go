package infrastructure

import (
	"time"

	bosherr "bosh/errors"
	boshdpresolv "bosh/infrastructure/devicepathresolver"
	boshlog "bosh/logger"
	boshplatform "bosh/platform"
)

type Provider struct {
	infrastructures map[string]Infrastructure
}

func NewProvider(logger boshlog.Logger, platform boshplatform.Platform) (p Provider) {
	metadataService := NewConcreteMetadataService(
		"http://169.254.169.254",
		NewDigDNSResolver(logger),
	)

	registry := NewConcreteRegistry()

	fs := platform.GetFs()
	dirProvider := platform.GetDirProvider()

	awsDevicePathResolver := boshdpresolv.NewAwsDevicePathResolver(500*time.Millisecond, platform.GetFs())
	vsphereDevicePathResolver := boshdpresolv.NewVsphereDevicePathResolver(500*time.Millisecond, platform.GetFs())
	dummyDevicePathResolver := boshdpresolv.NewDummyDevicePathResolver(1*time.Millisecond, fs)

	awsInfrastructure := NewAwsInfrastructure(
		metadataService,
		registry,
		platform,
		awsDevicePathResolver,
	)

	p.infrastructures = map[string]Infrastructure{
		"aws":     awsInfrastructure,
		"dummy":   NewDummyInfrastructure(fs, dirProvider, platform, dummyDevicePathResolver),
		"warden":  NewWardenInfrastructure(dirProvider, platform, dummyDevicePathResolver),
		"vsphere": NewVsphereInfrastructure(platform, vsphereDevicePathResolver, logger),
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
