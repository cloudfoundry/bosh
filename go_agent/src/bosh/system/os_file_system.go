package system

import (
	"bytes"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"strconv"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
	osuser "os/user"
)

type osFileSystem struct {
	logger boshlog.Logger
	logTag string
}

func NewOsFileSystem(logger boshlog.Logger) FileSystem {
	return osFileSystem{logger: logger, logTag: "File System"}
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

func (fs osFileSystem) WriteFileString(path, content string) (err error) {
	return fs.WriteFile(path, []byte(content))
}

func (fs osFileSystem) WriteFile(path string, content []byte) (err error) {
	err = fs.MkdirAll(filepath.Dir(path), os.ModePerm)
	if err != nil {
		err = bosherr.WrapError(err, "Creating dir to write file")
		return
	}

	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0666)
	if err != nil {
		err = bosherr.WrapError(err, "Creating file %s", path)
		return
	}

	defer file.Close()

	_, err = file.Write(content)
	if err != nil {
		err = bosherr.WrapError(err, "Writing content to file %s", path)
		return
	}

	return
}

func (fs osFileSystem) ConvergeFileContents(path string, content []byte) (written bool, err error) {
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

	_, err = file.Write(content)
	if err != nil {
		err = bosherr.WrapError(err, "Writing content to file %s", path)
		return
	}

	written = true
	return
}

func (fs osFileSystem) ReadFileString(path string) (content string, err error) {
	bytes, err := fs.ReadFile(path)
	if err != nil {
		return
	}

	content = string(bytes)
	return
}

func (fs osFileSystem) ReadFile(path string) (content []byte, err error) {
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

	content = bytes

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

func (fs osFileSystem) Symlink(oldPath, newPath string) error {
	fs.logger.Debug(fs.logTag, "Symlinking oldPath %s with newPath %s", oldPath, newPath)

	actualOldPath, err := filepath.EvalSymlinks(oldPath)
	if err != nil {
		return bosherr.WrapError(err, "Evaluating symlinks for %s", oldPath)
	}

	existingTargetedPath, err := filepath.EvalSymlinks(newPath)
	if err == nil {
		if existingTargetedPath == actualOldPath {
			return nil
		}

		err = os.Remove(newPath)
		if err != nil {
			return bosherr.WrapError(err, "Failed to delete symlimk at %s", newPath)
		}
	}

	containingDir := filepath.Dir(newPath)
	if !fs.FileExists(containingDir) {
		fs.MkdirAll(containingDir, os.FileMode(0700))
	}

	return os.Symlink(oldPath, newPath)
}

func (fs osFileSystem) ReadLink(symlinkPath string) (targetPath string, err error) {
	targetPath, err = os.Readlink(symlinkPath)
	return
}

func (fs osFileSystem) CopyFile(srcPath, dstPath string) error {
	fs.logger.Debug(fs.logTag, "Copying %s to %s", srcPath, dstPath)
	srcFile, err := os.Open(srcPath)
	if err != nil {
		return bosherr.WrapError(err, "Opening source path")
	}

	defer srcFile.Close()

	dstFile, err := os.Create(dstPath)
	if err != nil {
		return bosherr.WrapError(err, "Creating destination file")
	}

	defer dstFile.Close()

	_, err = io.Copy(dstFile, srcFile)
	if err != nil {
		return bosherr.WrapError(err, "Copying file")
	}

	return nil
}

func (fs osFileSystem) TempFile(prefix string) (file *os.File, err error) {
	fs.logger.Debug(fs.logTag, "Creating temp file with prefix %s", prefix)
	return ioutil.TempFile("", prefix)
}

func (fs osFileSystem) TempDir(prefix string) (path string, err error) {
	fs.logger.Debug(fs.logTag, "Creating temp dir with prefix %s", prefix)
	return ioutil.TempDir("", prefix)
}

func (fs osFileSystem) RemoveAll(fileOrDir string) (err error) {
	fs.logger.Debug(fs.logTag, "Remove all %s", fileOrDir)
	err = os.RemoveAll(fileOrDir)
	return
}

func (fs osFileSystem) Glob(pattern string) (matches []string, err error) {
	fs.logger.Debug(fs.logTag, "Glob '%s'", pattern)
	return filepath.Glob(pattern)
}

func (fs osFileSystem) filesAreIdentical(newContent []byte, filePath string) bool {
	existingStat, err := os.Stat(filePath)
	if err != nil || int64(len(newContent)) != existingStat.Size() {
		return false
	}

	existingContent, err := fs.ReadFile(filePath)
	if err != nil {
		return false
	}

	return bytes.Compare(newContent, existingContent) == 0
}
