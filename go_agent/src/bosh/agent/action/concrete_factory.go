package action

import (
	boshappl "bosh/agent/applier"
	boshtask "bosh/agent/task"
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
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
	applier boshappl.Applier,
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
			"list_disk":    newListDisk(settings, platform),
			"migrate_disk": newMigrateDisk(settings, platform),
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

func (f concreteFactory) Create(method string) (action Action, err error) {
	action, found := f.availableActions[method]
	if !found {
		err = bosherr.New("Could not create action with method %s", method)
	}
	return
}
