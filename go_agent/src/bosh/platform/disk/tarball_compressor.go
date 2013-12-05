package disk

import (
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

func (c tarballCompressor) CompressFilesInDir(dir string, filters []string) (tarball *os.File, err error) {
	tmpDir := c.fs.TempDir()
	tgzDir := filepath.Join(tmpDir, "BoshAgentTarball")
	err = c.fs.MkdirAll(tgzDir, os.ModePerm)
	if err != nil {
		return
	}

	defer c.fs.RemoveAll(tgzDir)

	filesToCopy, err := c.findFilesMatchingFilters(dir, filters)
	if err != nil {
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
			return
		}

		// Golang does not have a way of copying files and preserving file info...
		_, _, err = c.cmdRunner.RunCommand("cp", "-p", file, dst)
		if err != nil {
			return
		}
	}

	tarballPath := filepath.Join(tmpDir, "files.tgz")
	_, _, err = c.cmdRunner.RunCommand("tar", "czf", tarballPath, "-C", tgzDir, ".")
	if err != nil {
		return
	}

	tarball, err = c.fs.Open(tarballPath)
	return
}

func (c tarballCompressor) DecompressFileToDir(tarball *os.File, dir string) (err error) {
	_, _, err = c.cmdRunner.RunCommand("tar", "xzf", tarball.Name(), "-C", dir)
	if err != nil {
		return
	}

	return
}

func (c tarballCompressor) findFilesMatchingFilters(dir string, filters []string) (files []string, err error) {
	for _, filter := range filters {
		var newFiles []string

		newFiles, err = c.findFilesMatchingFilter(filepath.Join(dir, filter))
		if err != nil {
			return
		}

		files = append(files, newFiles...)
	}

	return
}

func (c tarballCompressor) findFilesMatchingFilter(filter string) (files []string, err error) {
	files, err = filepath.Glob(filter)
	if err != nil {
		return
	}

	// Ruby Dir.glob will include *.log when looking for **/*.log
	// Golang implementation will not do it automatically
	if strings.Contains(filter, "**/*") {
		var extraFiles []string

		updatedFilter := strings.Replace(filter, "**/*", "*", 1)
		extraFiles, err = c.findFilesMatchingFilter(updatedFilter)
		if err != nil {
			return
		}

		files = append(files, extraFiles...)
	}
	return
}
