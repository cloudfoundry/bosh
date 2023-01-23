package brats_test

import (
	"fmt"
	"time"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	"github.com/cloudfoundry/bosh-utils/uuid"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("postgres", func() {
	Context("postgres-15", func() {
		var (
			postgres15Manifest     string
			postgres13Manifest     string
			postgresDeploymentName string
		)

		BeforeEach(func() {
			var err error

			postgresDeploymentName, err = uuid.NewGenerator().Generate()
			Expect(err).NotTo(HaveOccurred())

			postgres15Manifest = bratsutils.AssetPath("postgres-manifest.yml")
			postgres13Manifest = bratsutils.AssetPath("postgres-13-manifest.yml")

			session := bratsutils.OuterBosh("deploy", "-n", postgres13Manifest,
				"-d", postgresDeploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
		})

		It("Upgrades from 13", func() {
			session := bratsutils.OuterBosh("deploy", "-n", postgres15Manifest,
				"-d", postgresDeploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
		})
	})
})
