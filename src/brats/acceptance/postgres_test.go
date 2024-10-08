package acceptance_test

import (
	"fmt"
	"time"

	"github.com/cloudfoundry/bosh-utils/uuid"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

var _ = Describe("postgres", func() {
	Context("postgres-15", func() {
		var (
			postgres15Manifest     string
			postgres13Manifest     string
			postgres10Manifest     string
			postgresDeploymentName string
		)

		It("Upgrades from 13", func() {
			var err error

			postgresDeploymentName, err = uuid.NewGenerator().Generate()
			Expect(err).NotTo(HaveOccurred())

			postgres15Manifest = utils.AssetPath("postgres-manifest.yml")
			postgres13Manifest = utils.AssetPath("postgres-13-manifest.yml")

			session := utils.OuterBosh("deploy", "-n", postgres13Manifest,
				"-d", postgresDeploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))

			session = utils.OuterBosh("deploy", "-n", postgres15Manifest,
				"-d", postgresDeploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
		})

		It("Upgrades from 10", func() {
			var err error

			postgresDeploymentName, err = uuid.NewGenerator().Generate()
			Expect(err).NotTo(HaveOccurred())

			postgres15Manifest = utils.AssetPath("postgres-manifest.yml")
			postgres10Manifest = utils.AssetPath("postgres-10-manifest.yml")

			session := utils.OuterBosh("deploy", "-n", postgres10Manifest,
				"-d", postgresDeploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))

			session = utils.OuterBosh("deploy", "-n", postgres15Manifest,
				"-d", postgresDeploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
		})
	})
})
