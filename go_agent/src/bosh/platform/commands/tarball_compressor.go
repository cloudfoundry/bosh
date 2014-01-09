package commands

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
)

type tarballCompressor struct {
	cmdRunner boshsys.CmdRunner
	fs        boshsys.FileSystem
	copier    copier
}

func NewTarballCompressor(cmdRunner boshsys.CmdRunner, fs boshsys.FileSystem) (c tarballCompressor) {
	c.cmdRunner = cmdRunner
	c.fs = fs
	c.copier = NewCopier(cmdRunner, fs)
	return
}

func (c tarballCompressor) CompressFilesInDir(dir string, filters []string) (tarballPath string, err error) {
	tgzDir, err := c.copier.FilteredCopyToTemp(dir, filters)
	if err != nil {
		err = bosherr.WrapError(err, "Copying filtered files to temp directory")
		return
	}

	defer c.fs.RemoveAll(tgzDir)

	tarball, err := c.fs.TempFile("bosh-platform-disk-TarballCompressor-CompressFilesInDir")
	if err != nil {
		err = bosherr.WrapError(err, "Creating temporary file for tarball")
		return
	}

	tarballPath = tarball.Name()

	_, _, err = c.cmdRunner.RunCommand("tar", "czf", tarballPath, "-C", tgzDir, ".")
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to tar")
		return
	}

	return
}

func (c tarballCompressor) DecompressFileToDir(tarballPath string, dir string) (err error) {
	_, _, err = c.cmdRunner.RunCommand("tar", "--no-same-owner", "-xzvf", tarballPath, "-C", dir)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to tar")
		return
	}

	return
}
