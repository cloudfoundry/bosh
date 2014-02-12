package blobstore_test

import (
	boshassert "bosh/assert"
	. "bosh/blobstore"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	fakeuuid "bosh/uuid/fakes"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
	"path/filepath"
	"strings"
)

func getExternalBlobstoreDependencies() (fs *fakesys.FakeFileSystem, runner *fakesys.FakeCmdRunner, uuidGen *fakeuuid.FakeGenerator, configPath string) {
	fs = &fakesys.FakeFileSystem{}
	runner = &fakesys.FakeCmdRunner{}
	uuidGen = &fakeuuid.FakeGenerator{}
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
	configPath = filepath.Join(dirProvider.EtcDir(), "blobstore-fake-provider.json")
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("external validate writes config file", func() {
			fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()

			options := map[string]string{"fake-key": "fake-value"}

			blobstore := NewExternalBlobstore("fake-provider", options, fs, runner, uuidGen, configPath)

			runner.CommandExistsValue = true
			assert.NoError(GinkgoT(), blobstore.Validate())

			s3CliConfig, err := fs.ReadFile(configPath)
			assert.NoError(GinkgoT(), err)

			expectedJson := map[string]string{"fake-key": "fake-value"}
			boshassert.MatchesJsonString(GinkgoT(), expectedJson, s3CliConfig)
		})
		It("external validate errors when command not in path", func() {

			fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()

			options := map[string]string{}

			blobstore := NewExternalBlobstore("fake-provider", options, fs, runner, uuidGen, configPath)

			assert.Error(GinkgoT(), blobstore.Validate())
		})
		It("external get", func() {

			fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()
			blobstore := NewExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

			tempFile, err := fs.TempFile("bosh-blobstore-external-TestGet")
			assert.NoError(GinkgoT(), err)

			fs.ReturnTempFile = tempFile
			defer fs.RemoveAll(tempFile.Name())

			fileName, err := blobstore.Get("fake-blob-id", "")
			assert.NoError(GinkgoT(), err)

			assert.Equal(GinkgoT(), 1, len(runner.RunCommands))
			assert.Equal(GinkgoT(), []string{
				"bosh-blobstore-fake-provider", "-c", configPath, "get",
				"fake-blob-id",
				tempFile.Name(),
			}, runner.RunCommands[0])

			assert.Equal(GinkgoT(), fileName, tempFile.Name())
			assert.True(GinkgoT(), fs.FileExists(tempFile.Name()))
		})
		It("external get errs when temp file create errs", func() {

			fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()
			blobstore := NewExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

			fs.TempFileError = errors.New("fake-error")

			fileName, err := blobstore.Get("fake-blob-id", "")
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-error")

			assert.Empty(GinkgoT(), fileName)
		})
		It("external get errs when external cli errs", func() {

			fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()
			blobstore := NewExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

			tempFile, err := fs.TempFile("bosh-blobstore-external-TestGetErrsWhenExternalCliErrs")
			assert.NoError(GinkgoT(), err)

			fs.ReturnTempFile = tempFile
			defer fs.RemoveAll(tempFile.Name())

			expectedCmd := []string{
				"bosh-blobstore-fake-provider", "-c", configPath, "get",
				"fake-blob-id",
				tempFile.Name(),
			}
			runner.AddCmdResult(strings.Join(expectedCmd, " "), fakesys.FakeCmdResult{Error: errors.New("fake-error")})

			fileName, err := blobstore.Get("fake-blob-id", "")
			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "fake-error")

			assert.Empty(GinkgoT(), fileName)
			assert.False(GinkgoT(), fs.FileExists(tempFile.Name()))
		})
		It("external clean up", func() {

			fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()
			blobstore := NewExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

			file, err := fs.TempFile("bosh-blobstore-external-TestCleanUp")
			assert.NoError(GinkgoT(), err)
			fileName := file.Name()

			defer fs.RemoveAll(fileName)

			err = blobstore.CleanUp(fileName)
			assert.NoError(GinkgoT(), err)
			assert.False(GinkgoT(), fs.FileExists(fileName))
		})
		It("external create", func() {

			fileName := "../../../fixtures/some.config"
			expectedPath, _ := filepath.Abs(fileName)

			fs, runner, uuidGen, configPath := getExternalBlobstoreDependencies()
			blobstore := NewExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

			uuidGen.GeneratedUuid = "some-uuid"

			blobId, fingerprint, err := blobstore.Create(fileName)
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), blobId, "some-uuid")
			assert.Empty(GinkgoT(), fingerprint)

			assert.Equal(GinkgoT(), 1, len(runner.RunCommands))
			assert.Equal(GinkgoT(), []string{
				"bosh-blobstore-fake-provider", "-c", configPath, "put",
				expectedPath, "some-uuid",
			}, runner.RunCommands[0])
		})
	})
}
