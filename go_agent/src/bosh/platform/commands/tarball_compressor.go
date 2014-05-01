package commands

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
)

type tarballCompressor struct {
	cmdRunner boshsys.CmdRunner
	fs        boshsys.FileSystem
}

func NewTarballCompressor(
	cmdRunner boshsys.CmdRunner,
	fs boshsys.FileSystem,
) tarballCompressor {
	return tarballCompressor{cmdRunner: cmdRunner, fs: fs}
}

func (c tarballCompressor) CompressFilesInDir(dir string) (string, error) {
	tarball, err := c.fs.TempFile("bosh-platform-disk-TarballCompressor-CompressFilesInDir")
	if err != nil {
		return "", bosherr.WrapError(err, "Creating temporary file for tarball")
	}

	tarballPath := tarball.Name()

	_, _, _, err = c.cmdRunner.RunCommand("tar", "czf", tarballPath, "-C", dir, ".")
	if err != nil {
		return "", bosherr.WrapError(err, "Shelling out to tar")
	}

	return tarballPath, nil
}

func (c tarballCompressor) DecompressFileToDir(tarballPath string, dir string) error {
	_, _, _, err := c.cmdRunner.RunCommand("tar", "--no-same-owner", "-xzvf", tarballPath, "-C", dir)
	if err != nil {
		return bosherr.WrapError(err, "Shelling out to tar")
	}

	return nil
}

func (c tarballCompressor) CleanUp(tarballPath string) error {
	return c.fs.RemoveAll(tarballPath)
}
