package action

import (
	boshappl "bosh/agent/applier"
	boshas "bosh/agent/applier/applyspec"
	boshcomp "bosh/agent/compiler"
	boshtask "bosh/agent/task"
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshmon "bosh/monitor"
	boshnotif "bosh/notification"
	boshplatform "bosh/platform"
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
	monitor boshmon.Monitor,
	specService boshas.V1Service,
) (factory Factory) {

	fs := platform.GetFs()
	runner := platform.GetRunner()
	compressor := platform.GetCompressor()

	factory = concreteFactory{
		availableActions: map[string]Action{
			"apply":        newApply(applier, specService),
			"drain":        newDrain(runner, fs, notifier, specService),
			"fetch_logs":   newLogs(compressor, blobstore),
			"get_task":     newGetTask(taskService),
			"get_state":    newGetState(settings, specService, monitor),
			"list_disk":    newListDisk(settings, platform),
			"migrate_disk": newMigrateDisk(settings, platform),
			"mount_disk":   newMountDisk(settings, platform),
			"ping":         newPing(),
			"prepare_network_change": newPrepareNetworkChange(),
			"ssh":             newSsh(settings, platform),
			"start":           newStart(monitor),
			"stop":            newStop(monitor),
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
