package acceptance_test

import (
	"fmt"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

var _ = Describe("postgres", func() {
	Context("postgres-15", func() {
		const upgradeTimeout = 20 * time.Minute

		It("Upgrades from 13", func() {
			postgresDeploymentName := fmt.Sprintf("postgres-13-to-postgres-15-%x", GinkgoT().RandomSeed())

			postgres13Manifest := utils.AssetPath("postgres-13-manifest.yml")
			session := utils.OuterBosh("deploy", "-n", postgres13Manifest,
				"-d", postgresDeploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
			)
			Eventually(session, upgradeTimeout).Should(gexec.Exit(0))

			postgres15Manifest := utils.AssetPath("postgres-manifest.yml")
			session = utils.OuterBosh("deploy", "-n", postgres15Manifest,
				"-d", postgresDeploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
			)
			Eventually(session, upgradeTimeout).Should(gexec.Exit(0))
		})
	})
})
