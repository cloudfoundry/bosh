package app

import (
	"encoding/json"

	bosherr "bosh/errors"
	boshplatform "bosh/platform"
	boshsys "bosh/system"
)

type Config struct {
	Platform boshplatform.ProviderOptions
}

func LoadConfigFromPath(fs boshsys.FileSystem, path string) (Config, error) {
	var config Config

	if path == "" {
		return config, nil
	}

	bytes, err := fs.ReadFile(path)
	if err != nil {
		return config, bosherr.WrapError(err, "Reading file")
	}

	err = json.Unmarshal(bytes, &config)
	if err != nil {
		return config, bosherr.WrapError(err, "Loading file")
	}

	return config, nil
}
