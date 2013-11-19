package system

import (
	bosherr "bosh/errors"
	"io/ioutil"
	"os"
	osuser "os/user"
	"path/filepath"
	"strconv"
)

type OsFileSystem struct {
}

func (fs OsFileSystem) HomeDir(username string) (homeDir string, err error) {
	user, err := osuser.Lookup(username)
	if err != nil {
		return
	}
	homeDir = user.HomeDir
	return
}

func (fs OsFileSystem) MkdirAll(path string, perm os.FileMode) (err error) {
	return os.MkdirAll(path, perm)
}

func (fs OsFileSystem) Chown(path, username string) (err error) {
	user, err := osuser.Lookup(username)
	if err != nil {
		return
	}

	uid, err := strconv.Atoi(user.Uid)
	if err != nil {
		return
	}

	gid, err := strconv.Atoi(user.Gid)
	if err != nil {
		return
	}

	err = os.Chown(path, uid, gid)
	return
}

func (fs OsFileSystem) Chmod(path string, perm os.FileMode) (err error) {
	return os.Chmod(path, perm)
}

func (fs OsFileSystem) WriteToFile(path, content string) (written bool, err error) {
	if fs.filesAreIdentical(content, path) {
		return
	}

	file, err := os.Create(path)
	if err != nil {
		return
	}
	defer file.Close()

	_, err = file.WriteString(content)
	if err != nil {
		return
	}

	written = true
	return
}

func (fs OsFileSystem) ReadFile(path string) (content string, err error) {
	file, err := os.Open(path)
	if err != nil {
		return
	}
	defer file.Close()

	bytes, err := ioutil.ReadAll(file)
	if err != nil {
		return
	}

	content = string(bytes)
	return
}

func (fs OsFileSystem) FileExists(path string) bool {
	_, err := os.Stat(path)
	if err != nil {
		return !os.IsNotExist(err)
	}
	return true
}

func (fs OsFileSystem) Symlink(oldPath, newPath string) (err error) {
	actualOldPath, err := filepath.EvalSymlinks(oldPath)
	if err != nil {
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

func (fs OsFileSystem) TempDir() (tmpDir string) {
	return os.TempDir()
}

func (fs OsFileSystem) RemoveAll(fileOrDir string) {
	os.RemoveAll(fileOrDir)
}

func (fs OsFileSystem) Open(path string) (file *os.File, err error) {
	return os.Open(path)
}

func (fs OsFileSystem) filesAreIdentical(newContent, filePath string) bool {
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
