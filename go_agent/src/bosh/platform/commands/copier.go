package commands

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"os"
	"path/filepath"
	"strings"
)

type copier struct {
	fs        boshsys.FileSystem
	cmdRunner boshsys.CmdRunner
}

func NewCopier(cmdRunner boshsys.CmdRunner, fs boshsys.FileSystem) (c copier) {
	c.cmdRunner = cmdRunner
	c.fs = fs
	return
}

func (c copier) FilteredCopyToTemp(dir string, filters []string) (tempDir string, err error) {
	tempDir, err = c.fs.TempDir("bosh-platform-disk-TarballCompressor-CompressFilesInDir")
	if err != nil {
		err = bosherr.WrapError(err, "Creating temporary directory")
		return
	}

	filesToCopy, err := c.findFilesMatchingFilters(dir, filters)
	if err != nil {
		err = bosherr.WrapError(err, "Finding files matching filters")
		c.fs.RemoveAll(tempDir)
		tempDir = ""
		return
	}

	for _, file := range filesToCopy {
		file = filepath.Clean(file)
		if !strings.HasPrefix(file, dir) {
			continue
		}

		relativePath := strings.Replace(file, dir, "", 1)
		dst := filepath.Join(tempDir, relativePath)

		err = c.fs.MkdirAll(filepath.Dir(dst), os.ModePerm)
		if err != nil {
			err = bosherr.WrapError(err, "Making destination directory for %s", file)
			c.fs.RemoveAll(tempDir)
			tempDir = ""
			return
		}

		// Golang does not have a way of copying files and preserving file info...
		_, _, err = c.cmdRunner.RunCommand("cp", "-p", file, dst)
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

func (c copier) findFilesMatchingFilters(dir string, filters []string) (files []string, err error) {
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

func (c copier) findFilesMatchingFilter(filter string) (files []string, err error) {
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
