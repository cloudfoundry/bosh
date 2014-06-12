package commands

import (
	"os"
	"path/filepath"

	"github.com/cloudfoundry/gofileutils/glob"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
	boshsys "bosh/system"
)

const cpCopierLogTag = "cpCopier"

type cpCopier struct {
	fs        boshsys.FileSystem
	cmdRunner boshsys.CmdRunner
	logger    boshlog.Logger
}

func NewCpCopier(
	cmdRunner boshsys.CmdRunner,
	fs boshsys.FileSystem,
	logger boshlog.Logger,
) cpCopier {
	return cpCopier{fs: fs, cmdRunner: cmdRunner, logger: logger}
}

func (c cpCopier) FilteredCopyToTemp(dir string, filters []string) (string, error) {
	tempDir, err := c.fs.TempDir("bosh-platform-commands-cpCopier-FilteredCopyToTemp")
	if err != nil {
		return "", bosherr.WrapError(err, "Creating temporary directory")
	}

	dirGlob := glob.NewDir(dir)
	filesToCopy, err := dirGlob.Glob(filters...)
	if err != nil {
		c.CleanUp(tempDir)
		return "", bosherr.WrapError(err, "Finding files matching filters")
	}

	for _, relativePath := range filesToCopy {
		src := filepath.Join(dir, relativePath)
		dst := filepath.Join(tempDir, relativePath)

		err = c.fs.MkdirAll(filepath.Dir(dst), os.ModePerm)
		if err != nil {
			c.CleanUp(tempDir)
			return "", bosherr.WrapError(err, "Making destination directory for %s", relativePath)
		}

		// Golang does not have a way of copying files and preserving file info...
		_, _, _, err = c.cmdRunner.RunCommand("cp", "-Rp", src, dst)
		if err != nil {
			c.CleanUp(tempDir)
			return "", bosherr.WrapError(err, "Shelling out to cp")
		}
	}

	err = c.fs.Chmod(tempDir, os.FileMode(0755))
	if err != nil {
		c.CleanUp(tempDir)
		return "", bosherr.WrapError(err, "Fixing permissions on temp dir")
	}

	return tempDir, nil
}

func (c cpCopier) CleanUp(tempDir string) {
	err := c.fs.RemoveAll(tempDir)
	if err != nil {
		c.logger.Error(cpCopierLogTag, "Failed to clean up temporary directory %s: %#v", tempDir, err)
	}
}
