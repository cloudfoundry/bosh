package system

// On Windows user is implemented via syscalls and does not require a C compiler
import "os/user"

import (
	"os"
	"path/filepath"
	"strings"
	"syscall"

	bosherr "github.com/cloudfoundry/bosh-utils/errors"
)

func (fs *osFileSystem) currentHomeDir() (string, error) {
	t, err := syscall.OpenCurrentProcessToken()
	if err != nil {
		return "", err
	}
	defer t.Close()
	return t.GetUserProfileDirectory()
}

func (fs *osFileSystem) homeDir(username string) (string, error) {
	u, err := user.Current()
	if err != nil {
		return "", err
	}
	// On Windows, looking up the home directory
	// is only supported for the current user.
	if username != "" && !strings.EqualFold(username, u.Name) {
		return "", bosherr.Errorf("Failed to get user '%s' home directory", username)
	}
	return u.HomeDir, nil
}

func (fs *osFileSystem) chown(path, username string) error {
	return bosherr.WrapError(error(syscall.EWINDOWS), "Chown not supported on Windows")
}

func isSlash(c uint8) bool { return c == '\\' || c == '/' }

func absPath(path string) (string, error) {
	if filepath.IsAbs(path) {
		return filepath.Clean(path), nil
	}
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	if len(path) > 0 && isSlash(path[0]) {
		return filepath.Join(filepath.VolumeName(wd), path), nil
	}
	return filepath.Join(wd, path), nil
}

func (fs *osFileSystem) symlinkPaths(oldPath, newPath string) (old, new string, err error) {
	// note: the type of the returned error is not *os.LinkError
	old, err = absPath(oldPath)
	if err != nil {
		return
	}
	new, err = absPath(newPath)
	if err != nil {
		return
	}
	return
}
