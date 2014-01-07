package system

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	"io"
	"io/ioutil"
	"os"
	osuser "os/user"
	"path/filepath"
	"strconv"
)

type osFileSystem struct {
	logger boshlog.Logger
	logTag string
	runner CmdRunner
}

func NewOsFileSystem(logger boshlog.Logger, runner CmdRunner) (fs FileSystem) {
	return osFileSystem{
		logger: logger,
		logTag: "File System",
		runner: runner,
	}
}

func (fs osFileSystem) HomeDir(username string) (homeDir string, err error) {
	fs.logger.Debug(fs.logTag, "Getting HomeDir for %s", username)

	user, err := osuser.Lookup(username)
	if err != nil {
		err = bosherr.WrapError(err, "Looking up user %s", username)
		return
	}
	homeDir = user.HomeDir

	fs.logger.Debug(fs.logTag, "HomeDir is %s", homeDir)
	return
}

func (fs osFileSystem) MkdirAll(path string, perm os.FileMode) (err error) {
	fs.logger.Debug(fs.logTag, "Making dir %s with perm %d", path, perm)
	return os.MkdirAll(path, perm)
}

func (fs osFileSystem) Chown(path, username string) (err error) {
	fs.logger.Debug(fs.logTag, "Chown %s to user %s", path, username)

	user, err := osuser.Lookup(username)
	if err != nil {
		err = bosherr.WrapError(err, "Looking up user %s", username)
		return
	}

	uid, err := strconv.Atoi(user.Uid)
	if err != nil {
		err = bosherr.WrapError(err, "Converting UID to integer")
		return
	}

	gid, err := strconv.Atoi(user.Gid)
	if err != nil {
		err = bosherr.WrapError(err, "Converting GID to integer")
		return
	}

	err = os.Chown(path, uid, gid)
	if err != nil {
		err = bosherr.WrapError(err, "Doing Chown")
		return
	}
	return
}

func (fs osFileSystem) Chmod(path string, perm os.FileMode) (err error) {
	fs.logger.Debug(fs.logTag, "Chmod %s to %d", path, perm)
	return os.Chmod(path, perm)
}

func (fs osFileSystem) WriteToFile(path, content string) (written bool, err error) {
	fs.logger.DebugWithDetails(fs.logTag, "Writing to file %s", path, content)

	if fs.filesAreIdentical(content, path) {
		return
	}

	err = fs.MkdirAll(filepath.Dir(path), os.ModePerm)
	if err != nil {
		err = bosherr.WrapError(err, "Making dir for file %s", path)
		return
	}

	file, err := os.Create(path)
	if err != nil {
		err = bosherr.WrapError(err, "Creating file %s", path)
		return
	}
	defer file.Close()

	_, err = file.WriteString(content)
	if err != nil {
		err = bosherr.WrapError(err, "Writing content to file %s", path)
		return
	}

	written = true
	return
}

func (fs osFileSystem) ReadFile(path string) (content string, err error) {
	fs.logger.Debug(fs.logTag, "Reading file %s", path)

	file, err := os.Open(path)
	if err != nil {
		err = bosherr.WrapError(err, "Opening file %s", path)
		return
	}
	defer file.Close()

	bytes, err := ioutil.ReadAll(file)
	if err != nil {
		err = bosherr.WrapError(err, "Reading file content %s", path)
		return
	}

	content = string(bytes)

	fs.logger.DebugWithDetails(fs.logTag, "Read content", content)
	return
}

func (fs osFileSystem) FileExists(path string) bool {
	fs.logger.Debug(fs.logTag, "Checking if file exists %s", path)

	_, err := os.Stat(path)
	if err != nil {
		return !os.IsNotExist(err)
	}
	return true
}

func (fs osFileSystem) Rename(oldPath, newPath string) (err error) {
	fs.logger.Debug(fs.logTag, "Renaming %s to %s", oldPath, newPath)

	fs.RemoveAll(newPath)
	return os.Rename(oldPath, newPath)
}

func (fs osFileSystem) Symlink(oldPath, newPath string) (err error) {
	fs.logger.Debug(fs.logTag, "Symlinking oldPath %s with newPath %s", oldPath, newPath)

	actualOldPath, err := filepath.EvalSymlinks(oldPath)
	if err != nil {
		err = bosherr.WrapError(err, "Evaluating symlinks for %s", oldPath)
		return
	}

	existingTargetedPath, err := filepath.EvalSymlinks(newPath)
	if err == nil {
		if existingTargetedPath == actualOldPath {
			return
		} else {
			err = os.Remove(newPath)
			if err != nil {
				err = bosherr.WrapError(err, "Failed to delete symlimk at %s", newPath)
				return
			}
		}
	}

	containingDir := filepath.Dir(newPath)
	if !fs.FileExists(containingDir) {
		fs.MkdirAll(containingDir, os.FileMode(0700))
	}

	return os.Symlink(oldPath, newPath)
}

func (fs osFileSystem) CopyDirEntries(srcPath, dstPath string) (err error) {
	_, _, err = fs.runner.RunCommand("cp", "-r", srcPath+"/.", dstPath)
	return
}

func (fs osFileSystem) CopyFile(srcPath, dstPath string) (err error) {
	fs.logger.Debug(fs.logTag, "Copying %s to %s", srcPath, dstPath)
	srcFile, err := os.Open(srcPath)
	if err != nil {
		err = bosherr.WrapError(err, "Opening source path")
		return
	}

	dstFile, err := os.Create(dstPath)
	if err != nil {
		err = bosherr.WrapError(err, "Creating destination file")
		return
	}

	_, err = io.Copy(dstFile, srcFile)
	if err != nil {
		err = bosherr.WrapError(err, "Copying file")
		return
	}
	return
}

func (fs osFileSystem) TempFile(prefix string) (file *os.File, err error) {
	fs.logger.Debug(fs.logTag, "Creating temp file with prefix %s", prefix)
	return ioutil.TempFile("", prefix)
}

func (fs osFileSystem) TempDir(prefix string) (path string, err error) {
	fs.logger.Debug(fs.logTag, "Creating temp dir with prefix %s", prefix)
	return ioutil.TempDir("", prefix)
}

func (fs osFileSystem) RemoveAll(fileOrDir string) {
	fs.logger.Debug(fs.logTag, "Remove all %s", fileOrDir)
	os.RemoveAll(fileOrDir)
}

func (fs osFileSystem) Open(path string) (file *os.File, err error) {
	fs.logger.Debug(fs.logTag, "Open %s", path)
	return os.Open(path)
}

func (fs osFileSystem) Glob(pattern string) (matches []string, err error) {
	fs.logger.Debug(fs.logTag, "Glob '%s'", pattern)
	return filepath.Glob(pattern)
}

func (fs osFileSystem) filesAreIdentical(newContent, filePath string) bool {
	newBytes := []byte(newContent)
	existingStat, err := os.Stat(filePath)
	if err != nil || int64(len(newBytes)) != existingStat.Size() {
		return false
	}

	existingContent, err := fs.ReadFile(filePath)
	if err != nil {
		return false
	}

	return newContent == existingContent
}
