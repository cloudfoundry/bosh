package brats_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"os/exec"
	"path/filepath"
	"time"

	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Bosh supporting old stemcells with gnatsd enabled director", func() {
	BeforeEach(startInnerBosh)
	AfterEach(stopInnerBosh)

	It("creates a deployment with stemcell version 3445", func() {
		deploysWithStemcellVersionSuccessfully("https://s3.amazonaws.com/bosh-core-stemcells/warden/bosh-stemcell-3445.11-warden-boshlite-ubuntu-trusty-go_agent.tgz")
	})

	It("creates a deployment with stemcell version 3431", func() {
		deploysWithStemcellVersionSuccessfully("https://s3.amazonaws.com/bosh-core-stemcells/warden/bosh-stemcell-3431.13-warden-boshlite-ubuntu-trusty-go_agent.tgz")
	})

	It("creates a deployment with stemcell version 3421", func() {
		deploysWithStemcellVersionSuccessfully("https://s3.amazonaws.com/bosh-core-stemcells/warden/bosh-stemcell-3421.26-warden-boshlite-ubuntu-trusty-go_agent.tgz")
	})

	It("creates a deployment with stemcell version 3363", func() {
		deploysWithStemcellVersionSuccessfully("https://s3.amazonaws.com/bosh-core-stemcells/warden/bosh-stemcell-3363.37-warden-boshlite-ubuntu-trusty-go_agent.tgz")
	})
})


func deploysWithStemcellVersionSuccessfully(stemcelURL string) {
	osConfManifestPath, err := filepath.Abs("../assets/os-conf-manifest.yml")
	Expect(err).ToNot(HaveOccurred())

	session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-stemcell", stemcelURL), GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, 5*time.Minute).Should(gexec.Exit(0))

	osConfRelease := "https://bosh.io/d/github.com/cloudfoundry/os-conf-release?v=12"
	session, err = gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-release", osConfRelease), GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, 2*time.Minute).Should(gexec.Exit(0))

	session, err = gexec.Start(exec.Command(boshBinaryPath, "-n",
		"deploy", osConfManifestPath,
		"-d", "os-conf-deployment"), GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, 3*time.Minute).Should(gexec.Exit(0))
}