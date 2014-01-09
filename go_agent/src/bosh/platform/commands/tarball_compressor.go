package commands

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
)

type tarballCompressor struct {
	cmdRunner boshsys.CmdRunner
	fs        boshsys.FileSystem
}

func NewTarballCompressor(cmdRunner boshsys.CmdRunner, fs boshsys.FileSystem) (c tarballCompressor) {
	c.cmdRunner = cmdRunner
	c.fs = fs
	return
}

func (c tarballCompressor) CompressFilesInDir(dir string) (tarballPath string, err error) {
	tarball, err := c.fs.TempFile("bosh-platform-disk-TarballCompressor-CompressFilesInDir")
	if err != nil {
		err = bosherr.WrapError(err, "Creating temporary file for tarball")
		return
	}

	tarballPath = tarball.Name()

	_, _, err = c.cmdRunner.RunCommand("tar", "czf", tarballPath, "-C", dir, ".")
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
