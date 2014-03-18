package action

import (
	boshappl "bosh/agent/applier"
	boshas "bosh/agent/applier/applyspec"
	boshcomp "bosh/agent/compiler"
	boshdrain "bosh/agent/drain"
	boshtask "bosh/agent/task"
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshinfrastructure "bosh/infrastructure"
	boshjobsuper "bosh/jobsupervisor"
	boshlog "bosh/logger"
	boshnotif "bosh/notification"
	boshplatform "bosh/platform"
	boshntp "bosh/platform/ntp"
	boshsettings "bosh/settings"
)

type concreteFactory struct {
	availableActions map[string]Action
}

func NewFactory(
	settings boshsettings.Service,
	platform boshplatform.Platform,
	infrastructure boshinfrastructure.Infrastructure,
	blobstore boshblob.Blobstore,
	taskService boshtask.Service,
	notifier boshnotif.Notifier,
	applier boshappl.Applier,
	compiler boshcomp.Compiler,
	jobSupervisor boshjobsuper.JobSupervisor,
	specService boshas.V1Service,
	drainScriptProvider boshdrain.DrainScriptProvider,
	logger boshlog.Logger,
) (factory Factory) {
	compressor := platform.GetCompressor()
	copier := platform.GetCopier()
	dirProvider := platform.GetDirProvider()
	vitalsService := platform.GetVitalsService()
	ntpService := boshntp.NewConcreteService(platform.GetFs(), dirProvider)

	factory = concreteFactory{
		availableActions: map[string]Action{
			"apply":        NewApply(applier, specService),
			"drain":        NewDrain(notifier, specService, drainScriptProvider),
			"fetch_logs":   NewLogs(compressor, copier, blobstore, dirProvider),
			"get_task":     NewGetTask(taskService),
			"get_state":    NewGetState(settings, specService, jobSupervisor, vitalsService, ntpService),
			"list_disk":    NewListDisk(settings, platform, logger),
			"migrate_disk": NewMigrateDisk(platform, dirProvider),
			"mount_disk":   NewMountDisk(settings, infrastructure, platform, dirProvider),
			"ping":         NewPing(),
			"prepare_network_change": NewPrepareNetworkChange(platform.GetFs(), settings),
			"ssh":                NewSsh(settings, platform, dirProvider),
			"start":              NewStart(jobSupervisor),
			"stop":               NewStop(jobSupervisor),
			"unmount_disk":       NewUnmountDisk(settings, platform),
			"compile_package":    NewCompilePackage(compiler),
			"release_apply_spec": NewReleaseApplySpec(platform),
		},
	}
	return
}

func (f concreteFactory) Create(method string) (action Action, err error) {
	action, found := f.availableActions[method]
	if !found {
		err = bosherr.New("Could not create action with method %s", method)
	}
	return
}
