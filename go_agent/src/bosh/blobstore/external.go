package blobstore

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	boshuuid "bosh/uuid"
	"encoding/json"
	"fmt"
	"path/filepath"
)

type external struct {
	fs             boshsys.FileSystem
	runner         boshsys.CmdRunner
	uuidGen        boshuuid.Generator
	configFilePath string
	provider       string
	options        map[string]string
}

func newExternalBlobstore(provider string, options map[string]string, fs boshsys.FileSystem, runner boshsys.CmdRunner, uuidGen boshuuid.Generator, configFilePath string) (blobstore Blobstore) {
	return external{
		provider:       provider,
		fs:             fs,
		runner:         runner,
		uuidGen:        uuidGen,
		configFilePath: configFilePath,
		options:        options,
	}
}

func (blobstore external) writeConfigFile() (err error) {
	configJson, err := json.Marshal(blobstore.options)
	if err != nil {
		err = bosherr.WrapError(err, "Marshalling JSON")
		return
	}

	_, err = blobstore.fs.WriteToFile(blobstore.configFilePath, string(configJson))
	if err != nil {
		err = bosherr.WrapError(err, "Writing config file")
		return
	}
	return
}

func (blobstore external) Get(blobId, _ string) (fileName string, err error) {
	file, err := blobstore.fs.TempFile("bosh-blobstore-external-Get")
	if err != nil {
		err = bosherr.WrapError(err, "Creating temporary file")
		return
	}

	fileName = file.Name()

	err = blobstore.run("get", blobId, fileName)
	if err != nil {
		blobstore.fs.RemoveAll(fileName)
		fileName = ""
	}

	return
}

func (blobstore external) CleanUp(fileName string) (err error) {
	blobstore.fs.RemoveAll(fileName)
	return
}

func (blobstore external) Create(fileName string) (blobId string, fingerprint string, err error) {
	filePath, err := filepath.Abs(fileName)
	if err != nil {
		err = bosherr.WrapError(err, "Getting absolute file path")
		return
	}

	blobId, err = blobstore.uuidGen.Generate()
	if err != nil {
		err = bosherr.WrapError(err, "Generating UUID")
		return
	}

	err = blobstore.run("put", filePath, blobId)
	return
}

func (blobstore external) Validate() (err error) {
	if !blobstore.runner.CommandExists(blobstore.executable()) {
		err = bosherr.New("executable %s not found in PATH", blobstore.executable())
		return
	}
	err = blobstore.writeConfigFile()
	return
}

func (blobstore external) run(method, src, dst string) (err error) {
	_, _, err = blobstore.runner.RunCommand(blobstore.executable(), "-c", blobstore.configFilePath, method, src, dst)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to %s cli")
		return
	}
	return
}

func (blobstore external) executable() (exec string) {
	return fmt.Sprintf("bosh-blobstore-%s", blobstore.provider)
}
