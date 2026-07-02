package acceptance_test

import (
	"fmt"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

var _ = Describe("postgres-release version matrix", func() {
	const deployTimeout = 20 * time.Minute

	manifest := utils.AssetPath("postgres-release-manifest.yml")

	type pgEntry struct {
		version  int
		previous int
	}

	DescribeTable("PostgreSQL version",
		func(e pgEntry) {
			deploymentName := fmt.Sprintf("postgres-release-%d-%x", e.version, GinkgoT().RandomSeed())

			By(fmt.Sprintf("deploying postgres-release at version %d", e.version))
			session := utils.OuterBosh("deploy", "-n", manifest,
				"-d", deploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", deploymentName),
				"-v", fmt.Sprintf("pg-version=%d", e.version),
			)
			Eventually(session, deployTimeout).Should(gexec.Exit(0))

			if e.previous > 0 {
				By(fmt.Sprintf("upgrading from postgres-release version %d to %d", e.previous, e.version))
				previousDeploymentName := fmt.Sprintf("postgres-release-%d-to-%d-%x", e.previous, e.version, GinkgoT().RandomSeed())

				By(fmt.Sprintf("deploying at version %d first", e.previous))
				session = utils.OuterBosh("deploy", "-n", manifest,
					"-d", previousDeploymentName,
					"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
					"-v", fmt.Sprintf("deployment-name=%s", previousDeploymentName),
					"-v", fmt.Sprintf("pg-version=%d", e.previous),
				)
				Eventually(session, deployTimeout).Should(gexec.Exit(0))

				By(fmt.Sprintf("upgrading to version %d", e.version))
				session = utils.OuterBosh("deploy", "-n", manifest,
					"-d", previousDeploymentName,
					"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
					"-v", fmt.Sprintf("deployment-name=%s", previousDeploymentName),
					"-v", fmt.Sprintf("pg-version=%d", e.version),
				)
				Eventually(session, deployTimeout).Should(gexec.Exit(0))
			}
		},
		Entry("deploys version 15", pgEntry{version: 15}),
		Entry("upgrades 15 -> 16", pgEntry{version: 16, previous: 15}),
		Entry("upgrades 16 -> 17", pgEntry{version: 17, previous: 16}),
		Entry("upgrades 17 -> 18", pgEntry{version: 18, previous: 17}),
	)
})
