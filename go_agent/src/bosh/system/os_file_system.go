package system

import (
	"io/ioutil"
	"os"
	osuser "os/user"
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
	if filesAreIdentical(content, path) {
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

func filesAreIdentical(newContent, filePath string) bool {
	existingFile, err := os.Open(filePath)
	if err != nil {
		return false
	}
	defer existingFile.Close()

	newBytes := []byte(newContent)
	existingStat, err := existingFile.Stat()
	if err != nil || int64(len(newBytes)) != existingStat.Size() {
		return false
	}

	existingBytes, err := ioutil.ReadAll(existingFile)
	if err != nil {
		return false
	}

	return newContent == string(existingBytes)
}
