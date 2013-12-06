package action

import (
	boshas "bosh/agent/applyspec"
	boshtask "bosh/agent/task"
	boshblob "bosh/blobstore"
	boshplatform "bosh/platform"
	boshsettings "bosh/settings"
)

type concreteFactory struct {
	availableActions map[string]Action
}

func NewFactory(
	settings *boshsettings.Provider,
	platform boshplatform.Platform,
	blobstore boshblob.Blobstore,
	taskService boshtask.Service,
	applier boshas.Applier,
) (factory Factory) {

	fs := platform.GetFs()
	compressor := platform.GetCompressor()

	factory = concreteFactory{
		availableActions: map[string]Action{
			"apply":        newApply(applier, fs, platform),
			"drain":        newDrain(),
			"fetch_logs":   newLogs(compressor, blobstore),
			"get_task":     newGetTask(taskService),
			"get_state":    newGetState(settings, fs),
			"mount_disk":   newMountDisk(settings, platform),
			"ping":         newPing(),
			"ssh":          newSsh(settings, platform),
			"start":        newStart(),
			"stop":         newStop(),
			"unmount_disk": newUnmountDisk(settings, platform),
		},
	}
	return
}

func (f concreteFactory) Create(method string) (action Action) {
	return f.availableActions[method]
}
