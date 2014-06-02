package blobstore_test

import (
	"errors"
	"path/filepath"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshassert "bosh/assert"
	. "bosh/blobstore"
	boshdir "bosh/settings/directories"
	fakesys "bosh/system/fakes"
	fakeuuid "bosh/uuid/fakes"
)

var _ = Describe("externalBlobstore", func() {
	var (
		fs         *fakesys.FakeFileSystem
		runner     *fakesys.FakeCmdRunner
		uuidGen    *fakeuuid.FakeGenerator
		configPath string
		blobstore  Blobstore
	)

	BeforeEach(func() {
		fs = fakesys.NewFakeFileSystem()
		runner = fakesys.NewFakeCmdRunner()
		uuidGen = &fakeuuid.FakeGenerator{}
		dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")
		configPath = filepath.Join(dirProvider.EtcDir(), "blobstore-fake-provider.json")
		blobstore = NewExternalBlobstore("fake-provider", map[string]interface{}{}, fs, runner, uuidGen, configPath)
	})

	Describe("Validate", func() {
		It("external validate writes config file", func() {
			options := map[string]interface{}{"fake-key": "fake-value"}

			blobstore := NewExternalBlobstore("fake-provider", options, fs, runner, uuidGen, configPath)

			runner.CommandExistsValue = true

			err := blobstore.Validate()
			Expect(err).ToNot(HaveOccurred())

			s3CliConfig, err := fs.ReadFileString(configPath)
			Expect(err).ToNot(HaveOccurred())

			expectedJSON := map[string]string{"fake-key": "fake-value"}
			boshassert.MatchesJSONString(GinkgoT(), expectedJSON, s3CliConfig)
		})

		It("external validate errors when command not in path", func() {
			options := map[string]interface{}{}

			blobstore := NewExternalBlobstore("fake-provider", options, fs, runner, uuidGen, configPath)

			err := blobstore.Validate()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("not found in PATH"))
		})
	})

	Describe("Get", func() {
		It("external get", func() {
			tempFile, err := fs.TempFile("bosh-blobstore-external-TestGet")
			Expect(err).ToNot(HaveOccurred())

			fs.ReturnTempFile = tempFile
			defer fs.RemoveAll(tempFile.Name())

			fileName, err := blobstore.Get("fake-blob-id", "")
			Expect(err).ToNot(HaveOccurred())

			Expect(len(runner.RunCommands)).To(Equal(1))
			Expect(runner.RunCommands[0]).To(Equal([]string{
				"bosh-blobstore-fake-provider", "-c", configPath, "get",
				"fake-blob-id",
				tempFile.Name(),
			}))

			Expect(fileName).To(Equal(tempFile.Name()))
			Expect(fs.FileExists(tempFile.Name())).To(BeTrue())
		})

		It("external get errs when temp file create errs", func() {
			fs.TempFileError = errors.New("fake-error")

			fileName, err := blobstore.Get("fake-blob-id", "")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("fake-error"))

			Expect(fileName).To(BeEmpty())
		})

		It("external get errs when external cli errs", func() {
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

			Expect(fileName).To(BeEmpty())
			Expect(fs.FileExists(tempFile.Name())).To(BeFalse())
		})
	})

	Describe("CleanUp", func() {
		It("external clean up", func() {
			file, err := fs.TempFile("bosh-blobstore-external-TestCleanUp")
			Expect(err).ToNot(HaveOccurred())
			fileName := file.Name()

			defer fs.RemoveAll(fileName)

			err = blobstore.CleanUp(fileName)
			Expect(err).ToNot(HaveOccurred())
			Expect(fs.FileExists(fileName)).To(BeFalse())
		})
	})

	Describe("Create", func() {
		It("external create", func() {
			fileName := "../../../fixtures/some.config"
			expectedPath, err := filepath.Abs(fileName)
			Expect(err).ToNot(HaveOccurred())

			uuidGen.GeneratedUuid = "some-uuid"

			blobID, fingerprint, err := blobstore.Create(fileName)
			Expect(err).ToNot(HaveOccurred())
			Expect(blobID).To(Equal("some-uuid"))
			Expect(fingerprint).To(BeEmpty())

			Expect(len(runner.RunCommands)).To(Equal(1))
			Expect(runner.RunCommands[0]).To(Equal([]string{
				"bosh-blobstore-fake-provider", "-c", configPath, "put",
				expectedPath, "some-uuid",
			}))
		})
	})
})
