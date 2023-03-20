package performance_test

import (
	"fmt"
	"strings"
	"time"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"testing"
)

func TestPerformance(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Performance Suite")
}

var (
	boshRelease,
	candidateWardenLinuxStemcellPath string
)

var _ = SynchronizedBeforeSuite(func() {
	bratsutils.Bootstrap()
	bratsutils.OuterBosh("upload-release", bratsutils.AssertEnvExists("BOSH_DIRECTOR_TARBALL_PATH"))
	directorReleasePath := bratsutils.AssertEnvExists("BOSH_DIRECTOR_RELEASE_PATH")
	session := bratsutils.OuterBosh("create-release", "--dir", directorReleasePath)
	Eventually(session, 1*time.Minute).Should(gexec.Exit())
	session = bratsutils.OuterBosh("upload-release", "--dir", directorReleasePath, "--rebase")
	Eventually(session, 1*time.Minute).Should(gexec.Exit())
}, func() {
	bratsutils.Bootstrap()
	candidateWardenLinuxStemcellPath = bratsutils.AssertEnvExists("CANDIDATE_STEMCELL_TARBALL_PATH")
})

var _ = AfterSuite(func() {
	bratsutils.StopInnerBosh()
})

var _ = AfterEach(func() {
	if !bratsutils.InnerBoshExists() {
		return
	}

	By("cleaning up deployments")
	session := bratsutils.Bosh("deployments", "--column=name")
	Eventually(session, 1*time.Minute).Should(gexec.Exit())
	deployments := strings.Fields(string(session.Out.Contents()))

	for _, deploymentName := range deployments {
		By(fmt.Sprintf("deleting deployment %v", deploymentName))
		if deploymentName == "" {
			continue
		}
		session := bratsutils.Bosh("delete-deployment", "-n", "-d", deploymentName)
		Eventually(session, 5*time.Minute).Should(gexec.Exit())
	}
})
