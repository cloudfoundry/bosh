package blobstore

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	boshuuid "bosh/uuid"
	"encoding/json"
	"path/filepath"
)

type s3 struct {
	fs             boshsys.FileSystem
	runner         boshsys.CmdRunner
	uuidGen        boshuuid.Generator
	bucketName     string
	configFilePath string
}

func newS3Blobstore(fs boshsys.FileSystem, runner boshsys.CmdRunner, uuidGen boshuuid.Generator, configFilePath string) (blobstore Blobstore) {
	return s3{
		fs:             fs,
		runner:         runner,
		uuidGen:        uuidGen,
		configFilePath: configFilePath,
	}
}

type s3CliConfig struct {
	AccessKey string
	Bucket    string
	SecretKey string
}

// Blobstore client for S3 with optional object encryption - Options include:
//
// [required] bucket_name
// [optional] encryption_key - encryption key that gets applied before the object is sent to S3
// [optional] access_key_id
// [optional] secret_access_key
//
// If access_key_id and secret_access_key are not present, the blobstore client
// operates in read only mode as a simple_blobstore_client
func (blobstore s3) ApplyOptions(opts map[string]string) (updated Blobstore, err error) {
	blobstore.bucketName = opts["bucket_name"]

	config := s3CliConfig{
		AccessKey: opts["access_key_id"],
		Bucket:    opts["bucket_name"],
		SecretKey: opts["secret_access_key"],
	}

	configJson, err := json.Marshal(config)
	if err != nil {
		err = bosherr.WrapError(err, "Marshalling JSON")
		return
	}

	_, err = blobstore.fs.WriteToFile(blobstore.configFilePath, string(configJson))
	if err != nil {
		err = bosherr.WrapError(err, "Writing config file")
		return
	}

	updated = blobstore
	return
}

func (blobstore s3) Get(blobId, _ string) (fileName string, err error) {
	file, err := blobstore.fs.TempFile("bosh-blobstore-s3-Get")
	if err != nil {
		err = bosherr.WrapError(err, "Creating temporary file")
		return
	}

	fileName = file.Name()

	_, _, err = blobstore.runner.RunCommand("s3", "-c", blobstore.configFilePath, "get", blobId, fileName)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to s3 cli")
		blobstore.fs.RemoveAll(fileName)
		fileName = ""
	}

	return
}

func (blobstore s3) CleanUp(fileName string) (err error) {
	blobstore.fs.RemoveAll(fileName)
	return
}

func (blobstore s3) Create(fileName string) (blobId string, fingerprint string, err error) {
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

	_, _, err = blobstore.runner.RunCommand("s3", "-c", blobstore.configFilePath, "put", filePath, blobId)
	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to s3 cli")
		return
	}
	return
}
