package bootstrap

import (
	"bosh/errors"
	"bosh/infrastructure"
	"bosh/platform"
	"bosh/settings"
	"bosh/system"
	"encoding/json"
	"path/filepath"
)

const (
	VCAP_USERNAME = "vcap"
	VCAP_BASE_DIR = "/var/vcap"
)

type bootstrap struct {
	fs             system.FileSystem
	infrastructure infrastructure.Infrastructure
	platform       platform.Platform
}

func New(fs system.FileSystem, inf infrastructure.Infrastructure, p platform.Platform) (b bootstrap) {
	b.fs = fs
	b.infrastructure = inf
	b.platform = p
	return
}

func (boot bootstrap) Run() (s settings.Settings, err error) {
	err = boot.infrastructure.SetupSsh(boot.platform, VCAP_USERNAME)
	if err != nil {
		return
	}

	s, err = boot.fetchSettings()
	if err != nil {
		return
	}

	err = boot.infrastructure.SetupNetworking(boot.platform, s.Networks)
	if err != nil {
		return
	}

	return
}

func (boot bootstrap) fetchSettings() (s settings.Settings, err error) {
	s, err = boot.infrastructure.GetSettings()
	if err != nil {
		err = errors.WrapError(err, "Error fetching settings")
		return
	}

	settingsJson, err := json.Marshal(s)
	if err != nil {
		err = errors.WrapError(err, "Error marshalling settings json")
		return
	}

	boot.fs.WriteToFile(filepath.Join(VCAP_BASE_DIR, "bosh", "settings.json"), string(settingsJson))
	return
}
