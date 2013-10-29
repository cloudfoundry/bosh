package agent

import (
	"fmt"
	"os"
	"path/filepath"
)

const (
	VCAP_USERNAME = "vcap"
)

func Run(fs FileSystem, infrastructure Infrastructure) {
	publicKey, err := infrastructure.GetPublicKey()
	if err != nil {
		failWithError("Error getting public key", err)
		return
	}

	homeDir, err := fs.HomeDir(VCAP_USERNAME)
	if err != nil {
		failWithError("Error finding home dir for user", err)
		return
	}

	sshPath := filepath.Join(homeDir, ".ssh")
	fs.MkdirAll(sshPath, os.FileMode(0700))
	fs.Chown(sshPath, VCAP_USERNAME)

	authKeysPath := filepath.Join(sshPath, "authorized_keys")
	err = fs.WriteToFile(authKeysPath, publicKey)
	if err != nil {
		failWithError("Error creating authorized_keys file", err)
		return
	}

	fs.Chown(authKeysPath, VCAP_USERNAME)
	fs.Chmod(authKeysPath, os.FileMode(0600))
}

func failWithError(message string, err error) {
	fmt.Fprintf(os.Stderr, "%s: %s", message, err.Error())
	os.Exit(1)
}
