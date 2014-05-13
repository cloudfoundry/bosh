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

	// Currently useServerNameAsID boolean setting is hard coded below
	// because we do not support arbitrary infrastructure configurations
	awsRegistry := NewConcreteRegistry(metadataService, false)
	openstackRegistry := NewConcreteRegistry(metadataService, true)

	fs := platform.GetFs()
	dirProvider := platform.GetDirProvider()

	mappedDevicePathResolver := boshdpresolv.NewMappedDevicePathResolver(500*time.Millisecond, fs)
	vsphereDevicePathResolver := boshdpresolv.NewVsphereDevicePathResolver(500*time.Millisecond, fs)
	dummyDevicePathResolver := boshdpresolv.NewDummyDevicePathResolver()

	awsInfrastructure := NewAwsInfrastructure(
		metadataService,
		awsRegistry,
		platform,
		mappedDevicePathResolver,
		logger,
	)

	openstackInfrastructure := NewOpenstackInfrastructure(
		metadataService,
		openstackRegistry,
		platform,
		mappedDevicePathResolver,
		logger,
	)

	p.infrastructures = map[string]Infrastructure{
		"aws":       awsInfrastructure,
		"openstack": openstackInfrastructure,
		"dummy":     NewDummyInfrastructure(fs, dirProvider, platform, dummyDevicePathResolver),
		"warden":    NewWardenInfrastructure(dirProvider, platform, dummyDevicePathResolver),
		"vsphere":   NewVsphereInfrastructure(platform, vsphereDevicePathResolver, logger),
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
