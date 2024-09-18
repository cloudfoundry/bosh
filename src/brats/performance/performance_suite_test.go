package performance_test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

func TestPerformance(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Performance Suite")
}

var candidateWardenLinuxStemcellPath string

var _ = SynchronizedBeforeSuite(func() {
	utils.Bootstrap()
	utils.OuterBosh("upload-release", utils.AssertEnvExists("BOSH_DIRECTOR_TARBALL_PATH"))
	directorReleasePath := utils.AssertEnvExists("BOSH_DIRECTOR_RELEASE_PATH")
	session := utils.OuterBosh("create-release", "--dir", directorReleasePath)
	Eventually(session, 1*time.Minute).Should(gexec.Exit())
	session = utils.OuterBosh("upload-release", "--dir", directorReleasePath, "--rebase")
	Eventually(session, 1*time.Minute).Should(gexec.Exit())
}, func() {
	utils.Bootstrap()
	candidateWardenLinuxStemcellPath = utils.AssertEnvExists("CANDIDATE_STEMCELL_TARBALL_PATH")
})

var _ = AfterSuite(func() {
	utils.StopInnerBosh()
})

var _ = AfterEach(func() {
	if !utils.InnerBoshExists() {
		return
	}

	By("cleaning up deployments")
	session := utils.Bosh("deployments", "--column=name")
	Eventually(session, 1*time.Minute).Should(gexec.Exit())
	deployments := strings.Fields(string(session.Out.Contents()))

	for _, deploymentName := range deployments {
		By(fmt.Sprintf("deleting deployment %v", deploymentName))
		if deploymentName == "" {
			continue
		}
		session := utils.Bosh("delete-deployment", "-n", "-d", deploymentName)
		Eventually(session, 5*time.Minute).Should(gexec.Exit())
	}
})
