package brats_test

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"regexp"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

func extractAzIpsMap(regex *regexp.Regexp, contents string) map[string][]string {
	out := map[string][]string{
		"z1": {},
		"z2": {},
	}

	instances := regex.FindAllStringSubmatch(contents, -1)
	Expect(instances).ToNot(BeNil())
	for _, q := range instances {
		out[q[1]] = append(out[q[1]], q[2])
	}

	return out
}

var _ = FDescribe("BoshDns", func() {
	Context("When deploy vms across different azs", func() {
		var deploymentName = "dns-with-templates"

		BeforeEach(func() {
			startInnerBosh()

			session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-stemcell", candidateWardenLinuxStemcellPath), GinkgoWriter, GinkgoWriter)
			Expect(err).ToNot(HaveOccurred())
			Eventually(session, 5*time.Minute).Should(gexec.Exit(0))

			manifestPath, err := filepath.Abs("../assets/dns-with-templates-manifest.yml")

			session, err = gexec.Start(exec.Command(
				boshBinaryPath, "deploy",
				"-n",
				"-d", deploymentName,
				manifestPath,
				"-v", fmt.Sprintf("dns-release-path=%s", dnsReleasePath),
				"-v", fmt.Sprintf("dns-release-version=%s", dnsReleaseVersion),
				"-v", "linked-template-release-path=../assets/linked-templates-release",
			), GinkgoWriter, GinkgoWriter)
			Expect(err).ToNot(HaveOccurred())
			Eventually(session, 6*time.Minute).Should(gexec.Exit(0))
		})

		AfterEach(stopInnerBosh)

		It("can find instances using the address helper", func() {
			session, err := gexec.Start(exec.Command(
				boshBinaryPath, "-n",
				"-d", deploymentName,
				"instances",
				"--column", "instance",
				"--column", "az",
				"--column", "ips",
			), GinkgoWriter, GinkgoWriter)
			Expect(err).ToNot(HaveOccurred())
			Eventually(session, time.Minute).Should(gexec.Exit(0))

			instanceList := session.Out.Contents()

			By("finding instances in all AZs", func() {
				matchExpression := regexp.MustCompile("provider\\S+\\s+(z1|z2)\\s+(\\S+)")
				knownProviders := extractAzIpsMap(matchExpression, string(instanceList))

				session, err = gexec.Start(exec.Command(boshBinaryPath,
					"-d", deploymentName,
					"run-errand", "query-all",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				Expect(session.Out).To(gbytes.Say("ANSWER: 3"))

				for _, ips := range knownProviders {
					for _, ip := range ips {
						Expect(string(session.Out.Contents())).To(ContainSubstring(ip))
					}
				}
			})

			By("finding instances filtering by AZ", func() {
				matchExpression := regexp.MustCompile("provider\\S+\\s+(z1)\\s+(\\S+)")
				knownProviders := extractAzIpsMap(matchExpression, string(instanceList))

				session, err = gexec.Start(exec.Command(boshBinaryPath,
					"-d", deploymentName,
					"run-errand", "query-with-az-filter",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				Expect(session.Out).To(gbytes.Say("ANSWER: 2"))

				for _, ips := range knownProviders {
					for _, ip := range ips {
						Expect(string(session.Out.Contents())).To(ContainSubstring(ip))
					}
				}
			})
		})
	})
})
