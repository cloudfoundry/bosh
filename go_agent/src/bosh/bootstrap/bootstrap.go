package bootstrap

import (
	"bosh/filesystem"
	"bosh/infrastructure"
	"fmt"
	"os"
	"path/filepath"
)

const (
	VCAP_USERNAME = "vcap"
)

type boostrap struct {
	fs             filesystem.FileSystem
	infrastructure infrastructure.Infrastructure
}

func New(fs filesystem.FileSystem, infrastructure infrastructure.Infrastructure) (b boostrap) {
	b.fs = fs
	b.infrastructure = infrastructure
	return
}

func (boot boostrap) Run() {
	publicKey, err := boot.infrastructure.GetPublicKey()
	if err != nil {
		failWithError("Error getting public key", err)
		return
	}

	homeDir, err := boot.fs.HomeDir(VCAP_USERNAME)
	if err != nil {
		failWithError("Error finding home dir for user", err)
		return
	}

	sshPath := filepath.Join(homeDir, ".ssh")
	boot.fs.MkdirAll(sshPath, os.FileMode(0700))
	boot.fs.Chown(sshPath, VCAP_USERNAME)

	authKeysPath := filepath.Join(sshPath, "authorized_keys")
	err = boot.fs.WriteToFile(authKeysPath, publicKey)
	if err != nil {
		failWithError("Error creating authorized_keys file", err)
		return
	}

	boot.fs.Chown(authKeysPath, VCAP_USERNAME)
	boot.fs.Chmod(authKeysPath, os.FileMode(0600))
}

func failWithError(message string, err error) {
	fmt.Fprintf(os.Stderr, "%s: %s", message, err.Error())
	os.Exit(1)
}
