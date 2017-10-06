package brats_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Brats", func() {

	BeforeEach(startInnerBosh)

	AfterEach(stopInnerBosh)

	Context("blobstore nginx", func() {
		Context("When nginx writes to access log", func() {
			var tempBlobstoreDir string

			BeforeEach(func() {
				var err error
				tempBlobstoreDir, err = ioutil.TempDir(os.TempDir(), "blobstore_access")
				Expect(err).ToNot(HaveOccurred())

				session, err := gexec.Start(exec.Command(boshBinaryPath, "upload-release", "-n", boshRelease), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				session, err = gexec.Start(exec.Command(outerBoshBinaryPath, "-d", "bosh", "scp", fmt.Sprintf("bosh:%s", BLOBSTORE_ACCESS_LOG), tempBlobstoreDir), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))
			})

			It("Should log in correct format", func() {
				accessContent, err := ioutil.ReadFile(filepath.Join(tempBlobstoreDir, "blobstore_access.log"))
				Expect(err).ToNot(HaveOccurred())
				Expect(string(accessContent)).To(ContainSubstring("CEF:0|CloudFoundry|BOSH|-|blobstore_api|"))
			})
		})
	})
})
