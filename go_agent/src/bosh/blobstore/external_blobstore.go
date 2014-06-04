package blobstore

import (
	"encoding/json"
	"fmt"
	"path/filepath"

	bosherr "bosh/errors"
	boshsys "bosh/system"
	boshuuid "bosh/uuid"
)

type externalBlobstore struct {
	fs             boshsys.FileSystem
	runner         boshsys.CmdRunner
	uuidGen        boshuuid.Generator
	configFilePath string
	provider       string
	options        map[string]interface{}
}

func NewExternalBlobstore(
	provider string,
	options map[string]interface{},
	fs boshsys.FileSystem,
	runner boshsys.CmdRunner,
	uuidGen boshuuid.Generator,
	configFilePath string,
) Blobstore {
	return externalBlobstore{
		provider:       provider,
		fs:             fs,
		runner:         runner,
		uuidGen:        uuidGen,
		configFilePath: configFilePath,
		options:        options,
	}
}

func (b externalBlobstore) Get(blobID, _ string) (string, error) {
	file, err := b.fs.TempFile("bosh-blobstore-externalBlobstore-Get")
	if err != nil {
		return "", bosherr.WrapError(err, "Creating temporary file")
	}

	fileName := file.Name()

	err = b.run("get", blobID, fileName)
	if err != nil {
		b.fs.RemoveAll(fileName)
		return "", err
	}

	return fileName, nil
}

func (b externalBlobstore) CleanUp(fileName string) error {
	return b.fs.RemoveAll(fileName)
}

func (b externalBlobstore) Create(fileName string) (string, string, error) {
	filePath, err := filepath.Abs(fileName)
	if err != nil {
		return "", "", bosherr.WrapError(err, "Getting absolute file path")
	}

	blobID, err := b.uuidGen.Generate()
	if err != nil {
		return "", "", bosherr.WrapError(err, "Generating UUID")
	}

	err = b.run("put", filePath, blobID)
	if err != nil {
		return "", "", bosherr.WrapError(err, "Making put command")
	}

	return blobID, "", nil
}

func (b externalBlobstore) Validate() error {
	if !b.runner.CommandExists(b.executable()) {
		return bosherr.New("executable %s not found in PATH", b.executable())
	}

	return b.writeConfigFile()
}

func (b externalBlobstore) writeConfigFile() error {
	configJSON, err := json.Marshal(b.options)
	if err != nil {
		return bosherr.WrapError(err, "Marshalling JSON")
	}

	err = b.fs.WriteFile(b.configFilePath, configJSON)
	if err != nil {
		return bosherr.WrapError(err, "Writing config file")
	}

	return nil
}

func (b externalBlobstore) run(method, src, dst string) (err error) {
	_, _, _, err = b.runner.RunCommand(b.executable(), "-c", b.configFilePath, method, src, dst)
	if err != nil {
		return bosherr.WrapError(err, "Shelling out to %s cli", b.executable())
	}

	return nil
}

func (b externalBlobstore) executable() string {
	return fmt.Sprintf("bosh-blobstore-%s", b.provider)
}
