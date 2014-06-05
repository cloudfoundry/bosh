package action

import (
	boshappl "bosh/agent/applier"
	boshas "bosh/agent/applier/applyspec"
	boshcomp "bosh/agent/compiler"
	boshdrain "bosh/agent/drain"
	boshtask "bosh/agent/task"
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
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
	settingsService boshsettings.Service,
	platform boshplatform.Platform,
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
			// Task management
			"ping":        NewPing(),
			"get_task":    NewGetTask(taskService),
			"cancel_task": NewCancelTask(taskService),

			// VM admin
			"ssh":        NewSsh(settingsService, platform, dirProvider),
			"fetch_logs": NewFetchLogs(compressor, copier, blobstore, dirProvider),

			// Job management
			"prepare":    NewPrepare(applier),
			"apply":      NewApply(applier, specService, settingsService),
			"start":      NewStart(jobSupervisor),
			"stop":       NewStop(jobSupervisor),
			"drain":      NewDrain(notifier, specService, drainScriptProvider, jobSupervisor),
			"get_state":  NewGetState(settingsService, specService, jobSupervisor, vitalsService, ntpService),
			"run_errand": NewRunErrand(specService, dirProvider.JobsDir(), platform.GetRunner(), logger),

			// Compilation
			"compile_package":    NewCompilePackage(compiler),
			"release_apply_spec": NewReleaseApplySpec(platform),

			// Disk management
			"list_disk":    NewListDisk(settingsService, platform, logger),
			"migrate_disk": NewMigrateDisk(platform, dirProvider),
			"mount_disk":   NewMountDisk(settingsService, platform, platform, dirProvider),
			"unmount_disk": NewUnmountDisk(settingsService, platform),

			// Networking
			"prepare_network_change":     NewPrepareNetworkChange(platform.GetFs(), settingsService),
			"prepare_configure_networks": NewPrepareConfigureNetworks(platform, settingsService),
			"configure_networks":         NewConfigureNetworks(),
		},
	}
	return
}

func (f concreteFactory) Create(method string) (Action, error) {
	action, found := f.availableActions[method]
	if !found {
		return nil, bosherr.New("Could not create action with method %s", method)
	}

	return action, nil
}
