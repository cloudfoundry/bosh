//+build !windows

package system

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	bosherr "github.com/cloudfoundry/bosh-utils/errors"
)

func (fs *osFileSystem) homeDir(username string) (string, error) {
	homeDir, err := fs.runCommand(fmt.Sprintf("echo ~%s", username))
	if err != nil {
		return "", bosherr.WrapErrorf(err, "Shelling out to get user '%s' home directory", username)
	}
	if strings.HasPrefix(homeDir, "~") {
		return "", bosherr.Errorf("Failed to get user '%s' home directory", username)
	}
	return homeDir, nil
}

func (fs *osFileSystem) currentHomeDir() (string, error) {
	return fs.HomeDir("")
}

func (fs *osFileSystem) chown(path, username string) error {
	uid, err := fs.runCommand(fmt.Sprintf("id -u %s", username))
	if err != nil {
		return bosherr.WrapErrorf(err, "Getting user id for '%s'", username)
	}

	uidAsInt, err := strconv.Atoi(uid)
	if err != nil {
		return bosherr.WrapError(err, "Converting UID to integer")
	}

	gid, err := fs.runCommand(fmt.Sprintf("id -g %s", username))
	if err != nil {
		return bosherr.WrapErrorf(err, "Getting group id for '%s'", username)
	}

	gidAsInt, err := strconv.Atoi(gid)
	if err != nil {
		return bosherr.WrapError(err, "Converting GID to integer")
	}

	err = os.Chown(path, uidAsInt, gidAsInt)
	if err != nil {
		return bosherr.WrapError(err, "Doing Chown")
	}

	return nil
}

func (fs *osFileSystem) symlinkPaths(oldPath, newPath string) (old, new string, err error) {
	return oldPath, newPath, nil
}
