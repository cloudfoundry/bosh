package system

import (
	bosherr "bosh/errors"
	"io/ioutil"
	"os"
	osuser "os/user"
	"path/filepath"
	"strconv"
)

type osFileSystem struct {
}

func NewOsFileSystem() (fs FileSystem) {
	return osFileSystem{}
}

func (fs osFileSystem) HomeDir(username string) (homeDir string, err error) {
	user, err := osuser.Lookup(username)
	if err != nil {
		err = bosherr.WrapError(err, "Looking up user %s", username)
		return
	}
	homeDir = user.HomeDir
	return
}

func (fs osFileSystem) MkdirAll(path string, perm os.FileMode) (err error) {
	return os.MkdirAll(path, perm)
}

func (fs osFileSystem) Chown(path, username string) (err error) {
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
	return os.Chmod(path, perm)
}

func (fs osFileSystem) WriteToFile(path, content string) (written bool, err error) {
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
	return
}

func (fs osFileSystem) FileExists(path string) bool {
	_, err := os.Stat(path)
	if err != nil {
		return !os.IsNotExist(err)
	}
	return true
}

func (fs osFileSystem) Symlink(oldPath, newPath string) (err error) {
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
	return os.TempDir()
}

func (fs osFileSystem) RemoveAll(fileOrDir string) {
	os.RemoveAll(fileOrDir)
}

func (fs osFileSystem) Open(path string) (file *os.File, err error) {
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
