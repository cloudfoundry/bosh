package commands

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"github.com/cloudfoundry/gofileutils/glob"
	"os"
	"path/filepath"
)

type cpCopier struct {
	fs        boshsys.FileSystem
	cmdRunner boshsys.CmdRunner
}

func NewCpCopier(cmdRunner boshsys.CmdRunner, fs boshsys.FileSystem) (c cpCopier) {
	c.cmdRunner = cmdRunner
	c.fs = fs
	return
}

func (c cpCopier) FilteredCopyToTemp(dir string, filters []string) (tempDir string, err error) {
	tempDir, err = c.fs.TempDir("bosh-platform-disk-TarballCompressor-CompressFilesInDir")
	if err != nil {
		err = bosherr.WrapError(err, "Creating temporary directory")
		return
	}

	dirGlob := glob.NewDir(dir)
	filesToCopy, err := dirGlob.Glob(filters...)
	if err != nil {
		err = bosherr.WrapError(err, "Finding files matching filters")
		c.fs.RemoveAll(tempDir)
		tempDir = ""
		return
	}

	for _, relativePath := range filesToCopy {
		src := filepath.Join(dir, relativePath)

		dst := filepath.Join(tempDir, relativePath)

		err = c.fs.MkdirAll(filepath.Dir(dst), os.ModePerm)
		if err != nil {
			err = bosherr.WrapError(err, "Making destination directory for %s", relativePath)
			c.fs.RemoveAll(tempDir)
			tempDir = ""
			return
		}

		// Golang does not have a way of copying files and preserving file info...
		_, _, err = c.cmdRunner.RunCommand("cp", "-Rp", src, dst)
		if err != nil {
			err = bosherr.WrapError(err, "Shelling out to cp")
			c.fs.RemoveAll(tempDir)
			tempDir = ""
			return
		}
	}

	err = c.fs.Chmod(tempDir, os.FileMode(0755))
	if err != nil {
		err = bosherr.WrapError(err, "Fixing permissions on temp dir")
		return
	}

	return
}

func (c cpCopier) CleanUp(tempDir string) {
	c.fs.RemoveAll(tempDir)
}
