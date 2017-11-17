package brats_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo/extensions/table"
	. "github.com/onsi/gomega"

	"fmt"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Blobstore", func() {
	var (
		deploymentName = "syslog"
		release        = "https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11"
	)

	uploadRelease := func(release string) {
		session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-release", release), GinkgoWriter, GinkgoWriter)

		Expect(err).ToNot(HaveOccurred())
		Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
	}

	uploadStemcell := func(stemcell string) {
		session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-stemcell", stemcell), GinkgoWriter, GinkgoWriter)

		Expect(err).ToNot(HaveOccurred())
		Eventually(session, 5*time.Minute).Should(gexec.Exit(0))
	}

	assetPath := func(filename string) string {
		path, err := filepath.Abs("../assets/" + filename)
		Expect(err).ToNot(HaveOccurred())

		return path
	}

	deploys := func(deploymentName string, errorCode int) {
		session, err := gexec.Start(
			exec.Command(
				boshBinaryPath,
				"-n", "deploy",
				"-d", deploymentName+"-deployment",
				assetPath(deploymentName+"-manifest.yml"),
			),
			GinkgoWriter, GinkgoWriter,
		)

		Expect(err).ToNot(HaveOccurred())

		Eventually(session, 3*time.Minute).Should(gexec.Exit(errorCode))
	}

	testDeployment := func(allowHttp bool, schema string, exitCode int) {
		url := schema + "://" + innerDirectorIP + ":25250"

		startInnerBoshWithParams(
			"-o "+assetPath("op-blobstore-https.yml"),
			fmt.Sprintf("-v allow_http=%t", allowHttp),
			"-v agent_blobstore_endpoint="+url,
		)

		uploadRelease(release)

		uploadStemcell(candidateWardenLinuxStemcellPath)

		deploys(deploymentName, exitCode)
	}

	AfterEach(stopInnerBosh)

	DescribeTable("with allow_http true", testDeployment,
		Entry("allows http connections", true, "http", 0),
		Entry("allows https connections", true, "https", 0),
	)

	DescribeTable("with allow_http false", testDeployment,
		Entry("does not allow http connections", false, "http", 1),
		Entry("allows https connections", false, "https", 0),
	)

	It("does not accept http traffic after turning off http traffic on nginx blobstore", func() {
		testDeployment(true, "http", 0)
		testDeployment(false, "http", 0)

		session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "recreate", "-d", deploymentName+"-deployment"), GinkgoWriter, GinkgoWriter)

		Expect(err).ToNot(HaveOccurred())
		Eventually(session, 2*time.Minute).Should(gexec.Exit(1))
	})

	It("continues accepting https traffic after turning off http traffic on nginx blobstore", func() {
		testDeployment(true, "https", 0)
		testDeployment(false, "https", 0)

		session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "recreate", "-d", deploymentName+"-deployment"), GinkgoWriter, GinkgoWriter)

		Expect(err).ToNot(HaveOccurred())
		Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
	})
})
