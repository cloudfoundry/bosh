package certs_test

import (
	"fmt"
	"os"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/bosh-credentials-info/certs"

	fakesys "github.com/cloudfoundry/bosh-utils/system/fakes"
)

var _ = Describe("GetCertInfo", func() {

	var (
		DIRS = []string{
			"blobstore",
			"director",
			"nats",
			"db",
		}
		fs *fakesys.FakeFileSystem
	)

	BeforeEach(func(){
		fs = fakesys.NewFakeFileSystem()
		for _, dir := range DIRS {
			err := fs.MkdirAll(fmt.Sprintf("%s/%s/%s", certs.BASE_JOB_DIR, dir, certs.CONFIG_DIR), os.ModeDir)
			Expect(err).NotTo(HaveOccurred())
		}
	})


	Context("When walking the filesystem", func() {
		BeforeEach(func(){
			for x := 1; x < 3; x++ {
				err := fs.WriteFileString(fmt.Sprintf("%s/%s/%s/%s", certs.BASE_JOB_DIR, DIRS[x], certs.CONFIG_DIR, certs.CERTS_FILE_NAME), "fake content")
				Expect(err).NotTo(HaveOccurred())
			}
		})

		It("identify the dirs that have certificate information to report on", func(){
			result := certs.GetCredsPaths(fs, certs.BASE_JOB_DIR)
			Expect(len(result)).To(Equal(2))

			for x := 0; x < len(result); x++ {
				Expect(result[x]).To(Equal(fmt.Sprintf("%s/%s/%s/%s", certs.BASE_JOB_DIR, DIRS[x+1], certs.CONFIG_DIR, certs.CERTS_FILE_NAME)))
			}
		})
	})
})