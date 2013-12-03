package system

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	"io/ioutil"
	"os"
	osuser "os/user"
	"path/filepath"
	"strconv"
)

type osFileSystem struct {
	logger boshlog.Logger
	logTag string
}

func NewOsFileSystem(logger boshlog.Logger) (fs FileSystem) {
	return osFileSystem{
		logger: logger,
		logTag: "File System",
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
	fs.logger.Debug(fs.logTag, "Writing to file %s\n********************\n%s\n********************", path, content)

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

	fs.logger.Debug(fs.logTag, "Read content:\n********************\n%s\n********************", content)
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
			return bosherr.New("Error creating symlink %s to %s, it already links to %s",
				newPath, oldPath, existingTargetedPath)
		}
	}

	return os.Symlink(oldPath, newPath)
}

func (fs osFileSystem) TempDir() (tmpDir string) {
	fs.logger.Debug(fs.logTag, "Getting temp dir")
	return os.TempDir()
}

func (fs osFileSystem) RemoveAll(fileOrDir string) {
	fs.logger.Debug(fs.logTag, "Remove all %s", fileOrDir)
	os.RemoveAll(fileOrDir)
}

func (fs osFileSystem) Open(path string) (file *os.File, err error) {
	fs.logger.Debug(fs.logTag, "Open %s", path)
	return os.Open(path)
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
