package commands

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"os"
	"path/filepath"
	"strings"
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

func (c tarballCompressor) CompressFilesInDir(dir string, filters []string) (tarballPath string, err error) {
	tgzDir, err := c.fs.TempDir("bosh-platform-disk-TarballCompressor-CompressFilesInDir")
	if err != nil {
		err = bosherr.WrapError(err, "Creating temporary directory")
		return
	}

	defer c.fs.RemoveAll(tgzDir)

	filesToCopy, err := c.findFilesMatchingFilters(dir, filters)
	if err != nil {
		err = bosherr.WrapError(err, "Finding files matching filters")
		return
	}

	for _, file := range filesToCopy {
		file = filepath.Clean(file)
		if !strings.HasPrefix(file, dir) {
			continue
		}

		relativePath := strings.Replace(file, dir, "", 1)
		dst := filepath.Join(tgzDir, relativePath)

		err = c.fs.MkdirAll(filepath.Dir(dst), os.ModePerm)
		if err != nil {
			err = bosherr.WrapError(err, "Making destination directory for %s", file)
			return
		}

		// Golang does not have a way of copying files and preserving file info...
		_, _, err = c.cmdRunner.RunCommand("cp", "-p", file, dst)
		if err != nil {
			err = bosherr.WrapError(err, "Shelling out to cp")
			return
		}
	}

	tarball, err := c.fs.TempFile("bosh-platform-disk-TarballCompressor-CompressFilesInDir")
	if err != nil {
		err = bosherr.WrapError(err, "Creating temporary file for tarball")
		return
	}

	err = c.fs.Chmod(tgzDir, os.FileMode(0755))
	if err != nil {
		err = bosherr.WrapError(err, "Fixing permissions on tarball base dir")
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

func (c tarballCompressor) findFilesMatchingFilters(dir string, filters []string) (files []string, err error) {
	for _, filter := range filters {
		var newFiles []string

		newFiles, err = c.findFilesMatchingFilter(filepath.Join(dir, filter))
		if err != nil {
			err = bosherr.WrapError(err, "Finding files matching filter %s", filter)
			return
		}

		files = append(files, newFiles...)
	}

	return
}

func (c tarballCompressor) findFilesMatchingFilter(filter string) (files []string, err error) {
	files, err = filepath.Glob(filter)
	if err != nil {
		err = bosherr.WrapError(err, "Doing glob with filter")
		return
	}

	// Ruby Dir.glob will include *.log when looking for **/*.log
	// Golang implementation will not do it automatically
	if strings.Contains(filter, "**/*") {
		var extraFiles []string

		updatedFilter := strings.Replace(filter, "**/*", "*", 1)
		extraFiles, err = c.findFilesMatchingFilter(updatedFilter)
		if err != nil {
			err = bosherr.WrapError(err, "Recursing into filter %s", updatedFilter)
			return
		}

		files = append(files, extraFiles...)
	}
	return
}
