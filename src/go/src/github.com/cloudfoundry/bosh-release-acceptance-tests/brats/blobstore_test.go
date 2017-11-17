package brats_test

import (
	"io/ioutil"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo/extensions/table"
	. "github.com/onsi/gomega"

	"fmt"
	"time"
)

var _ = Describe("Blobstore", func() {
	testDeployment := func(allowHttp bool, schema string, errorCode int) {
		startInnerBosh(
			fmt.Sprintf("-o %s", assetPath("op-blobstore-https.yml")),
			fmt.Sprintf("-v allow_http=%t", allowHttp),
			fmt.Sprintf("-v agent_blobstore_endpoint=%s://%s:25250", schema, innerDirectorIP),
		)

		uploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")
		uploadStemcell(candidateWardenLinuxStemcellPath)

		session, err := bosh("-n", "deploy", "-d", "syslog-deployment",
			assetPath("syslog-manifest.yml"),
		)

		mustExec(session, err, 3*time.Minute, errorCode)
	}

	AfterEach(func() {
		stopInnerBosh()
	})

	DescribeTable("with allow_http true", testDeployment,
		Entry("allows http connections", true, "http", 0),
		Entry("allows https connections", true, "https", 0),
	)

	DescribeTable("with allow_http false", testDeployment,
		Entry("does not allow http connections", false, "http", 1),
		Entry("allows https connections", false, "https", 0),
	)

	Context("blobstore nginx", func() {
		Context("When nginx writes to access log", func() {
			var tempBlobstoreDir string

			BeforeEach(func() {
				tempBlobstoreDir, err := ioutil.TempDir(os.TempDir(), "blobstore_access")
				Expect(err).ToNot(HaveOccurred())

				uploadRelease(boshRelease)

				session, err := outerBosh("-d", "bosh", "scp", fmt.Sprintf("bosh:%s", BLOBSTORE_ACCESS_LOG), tempBlobstoreDir)
				mustExec(session, err, 2*time.Minute, 0)
			})

			It("Should log in correct format", func() {
				accessContent, err := ioutil.ReadFile(filepath.Join(tempBlobstoreDir, "blobstore_access.log"))
				Expect(err).ToNot(HaveOccurred())
				Expect(string(accessContent)).To(ContainSubstring("CEF:0|CloudFoundry|BOSH|-|blobstore_api|"))
			})
		})
	})
})
