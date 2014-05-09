package blobstore

import (
	"encoding/json"
	"fmt"
	"path/filepath"

	bosherr "bosh/errors"
	boshsys "bosh/system"
	boshuuid "bosh/uuid"
)

type external struct {
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
) (blobstore Blobstore) {
	return external{
		provider:       provider,
		fs:             fs,
		runner:         runner,
		uuidGen:        uuidGen,
		configFilePath: configFilePath,
		options:        options,
	}
}

func (blobstore external) Get(blobID, _ string) (string, error) {
	file, err := blobstore.fs.TempFile("bosh-blobstore-external-Get")
	if err != nil {
		return "", bosherr.WrapError(err, "Creating temporary file")
	}

	fileName := file.Name()

	err = blobstore.run("get", blobID, fileName)
	if err != nil {
		blobstore.fs.RemoveAll(fileName)
		return "", err
	}

	return fileName, nil
}

func (blobstore external) CleanUp(fileName string) error {
	blobstore.fs.RemoveAll(fileName)
	return nil
}

func (blobstore external) Create(fileName string) (string, string, error) {
	filePath, err := filepath.Abs(fileName)
	if err != nil {
		return "", "", bosherr.WrapError(err, "Getting absolute file path")
	}

	blobID, err := blobstore.uuidGen.Generate()
	if err != nil {
		return "", "", bosherr.WrapError(err, "Generating UUID")
	}

	err = blobstore.run("put", filePath, blobID)
	if err != nil {
		return "", "", bosherr.WrapError(err, "Making put command")
	}

	return blobID, "", nil
}

func (blobstore external) Validate() error {
	if !blobstore.runner.CommandExists(blobstore.executable()) {
		return bosherr.New("executable %s not found in PATH", blobstore.executable())
	}

	return blobstore.writeConfigFile()
}

func (blobstore external) writeConfigFile() error {
	configJSON, err := json.Marshal(blobstore.options)
	if err != nil {
		return bosherr.WrapError(err, "Marshalling JSON")
	}

	err = blobstore.fs.WriteFile(blobstore.configFilePath, configJSON)
	if err != nil {
		return bosherr.WrapError(err, "Writing config file")
	}

	return nil
}

func (blobstore external) run(method, src, dst string) (err error) {
	_, _, _, err = blobstore.runner.RunCommand(blobstore.executable(), "-c", blobstore.configFilePath, method, src, dst)
	if err != nil {
		return bosherr.WrapError(err, "Shelling out to %s cli", blobstore.executable())
	}

	return nil
}

func (blobstore external) executable() string {
	return fmt.Sprintf("bosh-blobstore-%s", blobstore.provider)
}
