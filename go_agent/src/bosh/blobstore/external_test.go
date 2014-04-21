package blobstore_test

import (
	"errors"
	"path/filepath"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	boshassert "bosh/assert"
	. "bosh/blobstore"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	fakeuuid "bosh/uuid/fakes"
)

func init() {
	Describe("external", func() {
		var (
			fs         *fakesys.FakeFileSystem
			runner     *fakesys.FakeCmdRunner
			uuidGen    *fakeuuid.FakeGenerator
			configPath string
		)

		BeforeEach(func() {
			fs = fakesys.NewFakeFileSystem()
			runner = fakesys.NewFakeCmdRunner()
			uuidGen = &fakeuuid.FakeGenerator{}
			dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
			configPath = filepath.Join(dirProvider.EtcDir(), "blobstore-fake-provider.json")
		})

		It("external validate writes config file", func() {
			options := map[string]string{"fake-key": "fake-value"}

			blobstore := NewExternalBlobstore("fake-provider", options, fs, runner, uuidGen, configPath)

			runner.CommandExistsValue = true
			assert.NoError(GinkgoT(), blobstore.Validate())

			s3CliConfig, err := fs.ReadFileString(configPath)
			Expect(err).ToNot(HaveOccurred())

			expectedJSON := map[string]string{"fake-key": "fake-value"}
			boshassert.MatchesJSONString(GinkgoT(), expectedJSON, s3CliConfig)
		})

		It("external validate errors when command not in path", func() {
			options := map[string]string{}

			blobstore := NewExternalBlobstore("fake-provider", options, fs, runner, uuidGen, configPath)

			assert.Error(GinkgoT(), blobstore.Validate())
		})

		It("external get", func() {
			blobstore := NewExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

			tempFile, err := fs.TempFile("bosh-blobstore-external-TestGet")
			Expect(err).ToNot(HaveOccurred())

			fs.ReturnTempFile = tempFile
			defer fs.RemoveAll(tempFile.Name())

			fileName, err := blobstore.Get("fake-blob-id", "")
			Expect(err).ToNot(HaveOccurred())

			Expect(1).To(Equal(len(runner.RunCommands)))
			assert.Equal(GinkgoT(), []string{
				"bosh-blobstore-fake-provider", "-c", configPath, "get",
				"fake-blob-id",
				tempFile.Name(),
			}, runner.RunCommands[0])

			Expect(fileName).To(Equal(tempFile.Name()))
			Expect(fs.FileExists(tempFile.Name())).To(BeTrue())
		})

		It("external get errs when temp file create errs", func() {
			blobstore := NewExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

			fs.TempFileError = errors.New("fake-error")

			fileName, err := blobstore.Get("fake-blob-id", "")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-error"))

			assert.Empty(GinkgoT(), fileName)
		})

		It("external get errs when external cli errs", func() {
			blobstore := NewExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

			tempFile, err := fs.TempFile("bosh-blobstore-external-TestGetErrsWhenExternalCliErrs")
			Expect(err).ToNot(HaveOccurred())

			fs.ReturnTempFile = tempFile
			defer fs.RemoveAll(tempFile.Name())

			expectedCmd := []string{
				"bosh-blobstore-fake-provider", "-c", configPath, "get",
				"fake-blob-id",
				tempFile.Name(),
			}
			runner.AddCmdResult(strings.Join(expectedCmd, " "), fakesys.FakeCmdResult{Error: errors.New("fake-error")})

			fileName, err := blobstore.Get("fake-blob-id", "")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-error"))

			assert.Empty(GinkgoT(), fileName)
			Expect(fs.FileExists(tempFile.Name())).To(BeFalse())
		})

		It("external clean up", func() {
			blobstore := NewExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

			file, err := fs.TempFile("bosh-blobstore-external-TestCleanUp")
			Expect(err).ToNot(HaveOccurred())
			fileName := file.Name()

			defer fs.RemoveAll(fileName)

			err = blobstore.CleanUp(fileName)
			Expect(err).ToNot(HaveOccurred())
			Expect(fs.FileExists(fileName)).To(BeFalse())
		})

		It("external create", func() {
			fileName := "../../../fixtures/some.config"
			expectedPath, _ := filepath.Abs(fileName)

			blobstore := NewExternalBlobstore("fake-provider", map[string]string{}, fs, runner, uuidGen, configPath)

			uuidGen.GeneratedUuid = "some-uuid"

			blobID, fingerprint, err := blobstore.Create(fileName)
			Expect(err).ToNot(HaveOccurred())
			Expect(blobID).To(Equal("some-uuid"))
			assert.Empty(GinkgoT(), fingerprint)

			Expect(1).To(Equal(len(runner.RunCommands)))
			assert.Equal(GinkgoT(), []string{
				"bosh-blobstore-fake-provider", "-c", configPath, "put",
				expectedPath, "some-uuid",
			}, runner.RunCommands[0])
		})
	})
}
