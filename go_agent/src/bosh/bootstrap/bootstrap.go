package bootstrap

import (
	"bosh/filesystem"
	"bosh/infrastructure"
	"bosh/platform"
	"bosh/settings"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

const (
	VCAP_USERNAME = "vcap"
	VCAP_BASE_DIR = "/var/vcap"
)

type bootstrap struct {
	fs             filesystem.FileSystem
	infrastructure infrastructure.Infrastructure
	platform       platform.Platform
}

func New(fs filesystem.FileSystem, inf infrastructure.Infrastructure, p platform.Platform) (b bootstrap) {
	b.fs = fs
	b.infrastructure = inf
	b.platform = p
	return
}

func (boot bootstrap) Run() (err error) {
	err = boot.setupSsh()
	if err != nil {
		return
	}

	s, err := boot.fetchSettings()
	if err != nil {
		return
	}

	err = boot.infrastructure.SetupNetworking(boot.platform, s.Networks)
	if err != nil {
		return
	}

	return
}

func (boot bootstrap) setupSsh() (err error) {
	publicKey, err := boot.infrastructure.GetPublicKey()
	if err != nil {
		return wrapError(err, "Error getting public key")
	}

	homeDir, err := boot.fs.HomeDir(VCAP_USERNAME)
	if err != nil {
		return wrapError(err, "Error finding home dir for user")
	}

	sshPath := filepath.Join(homeDir, ".ssh")
	boot.fs.MkdirAll(sshPath, os.FileMode(0700))
	boot.fs.Chown(sshPath, VCAP_USERNAME)

	authKeysPath := filepath.Join(sshPath, "authorized_keys")
	err = boot.fs.WriteToFile(authKeysPath, publicKey)
	if err != nil {
		return wrapError(err, "Error creating authorized_keys file")
	}

	boot.fs.Chown(authKeysPath, VCAP_USERNAME)
	boot.fs.Chmod(authKeysPath, os.FileMode(0600))
	return
}

func (boot bootstrap) fetchSettings() (s settings.Settings, err error) {
	s, err = boot.infrastructure.GetSettings()
	if err != nil {
		err = wrapError(err, "Error fetching settings")
		return
	}

	settingsJson, err := json.Marshal(s)
	if err != nil {
		err = wrapError(err, "Error marshalling settings json")
		return
	}

	boot.fs.WriteToFile(filepath.Join(VCAP_BASE_DIR, "bosh", "settings.json"), string(settingsJson))
	return
}

func wrapError(err error, msg string) (newErr error) {
	return errors.New(fmt.Sprintf("%s: %s", msg, err.Error()))
}
