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
	blobstore boshblob.Blobstore,
	taskService boshtask.Service,
	notifier boshnotif.Notifier,
	applier boshappl.Applier,
	compiler boshcomp.Compiler,
	jobSupervisor boshjobsuper.JobSupervisor,
	specService boshas.V1Service,
	drainScriptProvider boshdrain.DrainScriptProvider,
) (factory Factory) {
	compressor := platform.GetCompressor()
	copier := platform.GetCopier()
	dirProvider := platform.GetDirProvider()
	vitalsService := platform.GetVitalsService()
	ntpService := boshntp.NewConcreteService(platform.GetFs(), dirProvider)

	factory = concreteFactory{
		availableActions: map[string]Action{
			"apply":        newApply(applier, specService),
			"drain":        newDrain(notifier, specService, drainScriptProvider),
			"fetch_logs":   newLogs(compressor, copier, blobstore, dirProvider),
			"get_task":     newGetTask(taskService),
			"get_state":    newGetState(settings, specService, jobSupervisor, vitalsService, ntpService),
			"list_disk":    newListDisk(settings, platform),
			"migrate_disk": newMigrateDisk(settings, platform, dirProvider),
			"mount_disk":   newMountDisk(settings, platform, dirProvider),
			"ping":         newPing(),
			"prepare_network_change": newPrepareNetworkChange(),
			"ssh":             newSsh(settings, platform, dirProvider),
			"start":           newStart(jobSupervisor),
			"stop":            newStop(jobSupervisor),
			"unmount_disk":    newUnmountDisk(settings, platform),
			"compile_package": newCompilePackage(compiler),
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
