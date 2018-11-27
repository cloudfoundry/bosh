//+build !windows

package system

import (
	"fmt"
	"strings"

	"errors"
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

func (fs *osFileSystem) chown(path, owner string) error {
	if owner == "" {
		return errors.New("Failed to lookup user ''")
	}

	var group string
	var err error

	ownerSplit := strings.Split(owner, ":")
	user := ownerSplit[0]

	if len(ownerSplit) <= 1 {
		group, err = fs.runCommand(fmt.Sprintf("id -g %s", user))
		if err != nil {
			return bosherr.WrapErrorf(err, "Failed to lookup user '%s'", user)
		}
	} else {
		group = ownerSplit[1]
	}

	_, err = fs.runCommand(fmt.Sprintf("chown '%s:%s' '%s'", user, group, path))
	if err != nil {
		return bosherr.WrapError(err, "Failed to chown")
	}

	return nil
}

func (fs *osFileSystem) symlinkPaths(oldPath, newPath string) (old, new string, err error) {
	return oldPath, newPath, nil
}
