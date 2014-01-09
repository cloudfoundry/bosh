package action

import (
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshcmd "bosh/platform/commands"
	boshdirs "bosh/settings/directories"
	"path/filepath"
)

type logsAction struct {
	compressor  boshcmd.Compressor
	copier      boshcmd.Copier
	blobstore   boshblob.Blobstore
	settingsDir boshdirs.DirectoriesProvider
}

func newLogs(compressor boshcmd.Compressor, copier boshcmd.Copier, blobstore boshblob.Blobstore, settingsDir boshdirs.DirectoriesProvider) (action logsAction) {
	action.compressor = compressor
	action.copier = copier
	action.blobstore = blobstore
	action.settingsDir = settingsDir
	return
}

func (a logsAction) IsAsynchronous() bool {
	return true
}

func (a logsAction) Run(logType string, filters []string) (value interface{}, err error) {
	var logsDir string

	switch logType {
	case "job":
		if len(filters) == 0 {
			filters = []string{"**/*.log"}
		}
		logsDir = filepath.Join(a.settingsDir.BaseDir(), "sys", "log")
	case "agent":
		if len(filters) == 0 {
			filters = []string{"**/*"}
		}
		logsDir = filepath.Join(a.settingsDir.BaseDir(), "bosh", "log")
	default:
		err = bosherr.New("Invalid log type")
		return
	}

	tmpDir, err := a.copier.FilteredCopyToTemp(logsDir, filters)
	if err != nil {
		err = bosherr.WrapError(err, "Copying filtered files to temp directory")
		return
	}

	defer a.copier.CleanUp(tmpDir)

	tarball, err := a.compressor.CompressFilesInDir(tmpDir)
	if err != nil {
		err = bosherr.WrapError(err, "Making logs tarball")
		return
	}

	blobId, _, err := a.blobstore.Create(tarball)
	if err != nil {
		err = bosherr.WrapError(err, "Create file on blobstore")
		return
	}

	value = map[string]string{"blobstore_id": blobId}
	return
}
