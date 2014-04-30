package commands_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	boshlog "bosh/logger"
	. "bosh/platform/commands"
	boshsys "bosh/system"
)

var _ = Describe("cpCopier", func() {
	var (
		fs        boshsys.FileSystem
		cmdRunner boshsys.CmdRunner
		cpCopier  Copier
	)

	BeforeEach(func() {
		logger := boshlog.NewLogger(boshlog.LevelNone)
		fs = boshsys.NewOsFileSystem(logger)
		cmdRunner = boshsys.NewExecCmdRunner(logger)
		cpCopier = NewCpCopier(cmdRunner, fs, logger)
	})

	Describe("FilteredCopyToTemp", func() {
		copierFixtureSrcDir := func() string {
			pwd, err := os.Getwd()
			Expect(err).ToNot(HaveOccurred())
			return filepath.Join(pwd, "..", "..", "..", "..", "fixtures", "test_filtered_copy_to_temp")
		}

		It("filtered copy to temp", func() {
			srcDir := copierFixtureSrcDir()
			dstDir, err := cpCopier.FilteredCopyToTemp(srcDir, []string{
				"**/*.stdout.log",
				"*.stderr.log",
				"../some.config",
				"some_directory/**/*",
			})
			Expect(err).ToNot(HaveOccurred())

			defer os.RemoveAll(dstDir)

			tarDirStat, err := os.Stat(dstDir)
			Expect(err).ToNot(HaveOccurred())
			Expect(os.FileMode(0755)).To(Equal(tarDirStat.Mode().Perm()))

			content, err := fs.ReadFileString(dstDir + "/app.stdout.log")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "this is app stdout")

			content, err = fs.ReadFileString(dstDir + "/app.stderr.log")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "this is app stderr")

			content, err = fs.ReadFileString(dstDir + "/other_logs/other_app.stdout.log")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "this is other app stdout")

			content, err = fs.ReadFileString(dstDir + "/other_logs/more_logs/more.stdout.log")
			Expect(err).ToNot(HaveOccurred())
			assert.Contains(GinkgoT(), content, "this is more stdout")

			Expect(fs.FileExists(dstDir + "/some_directory")).To(BeTrue())
			Expect(fs.FileExists(dstDir + "/some_directory/sub_dir")).To(BeTrue())
			Expect(fs.FileExists(dstDir + "/some_directory/sub_dir/other_sub_dir")).To(BeTrue())

			_, err = fs.ReadFile(dstDir + "/other_logs/other_app.stderr.log")
			Expect(err).To(HaveOccurred())

			_, err = fs.ReadFile(dstDir + "/../some.config")
			Expect(err).To(HaveOccurred())
		})
	})

	Describe("CleanUp", func() {
		It("cleans up", func() {
			tempDir := filepath.Join(os.TempDir(), "test-copier-cleanup")
			fs.MkdirAll(tempDir, os.ModePerm)

			cpCopier.CleanUp(tempDir)

			_, err := os.Stat(tempDir)
			Expect(err).To(HaveOccurred())
		})
	})
})
