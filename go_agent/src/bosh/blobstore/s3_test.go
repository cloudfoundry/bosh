package blobstore

import (
	boshassert "bosh/assert"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
	fakeuuid "bosh/uuid/fakes"
	"github.com/stretchr/testify/assert"
	"os"
	"path/filepath"
	"testing"
)

func TestSettingTheOptions(t *testing.T) {
	fs, runner, uuidGen := getS3BlobstoreDependencies()

	_, err := newS3Blobstore(fs, runner, uuidGen).ApplyOptions(map[string]string{
		"access_key_id":     "some-access-key",
		"secret_access_key": "some-secret-key",
		"bucket_name":       "some-bucket",
	})
	assert.NoError(t, err)

	s3CliConfig, err := fs.ReadFile("/var/vcap/etc/s3cli")
	assert.NoError(t, err)

	expectedJson := map[string]string{
		"AccessKey": "some-access-key",
		"SecretKey": "some-secret-key",
		"Bucket":    "some-bucket",
	}
	boshassert.MatchesJsonString(t, expectedJson, s3CliConfig)
}

func TestCreate(t *testing.T) {
	file, _ := os.Open("../../../fixtures/some.config")
	expectedPath, _ := filepath.Abs(file.Name())

	fs, runner, uuidGen := getS3BlobstoreDependencies()
	blobstore := newS3Blobstore(fs, runner, uuidGen)

	uuidGen.GeneratedUuid = "some-uuid"

	blobId, err := blobstore.Create(file)
	assert.NoError(t, err)
	assert.Equal(t, blobId, "some-uuid")

	configPath := filepath.Join(boshsettings.VCAP_BASE_DIR, "etc", "s3cli")

	assert.Equal(t, 1, len(runner.RunCommands))
	assert.Equal(t, []string{"s3", "-c", configPath, "put", expectedPath, "some-uuid"}, runner.RunCommands[0])
}

func getS3BlobstoreDependencies() (fs *fakesys.FakeFileSystem, runner *fakesys.FakeCmdRunner, uuidGen *fakeuuid.FakeGenerator) {
	fs = &fakesys.FakeFileSystem{}
	runner = &fakesys.FakeCmdRunner{}
	uuidGen = &fakeuuid.FakeGenerator{}
	return
}
