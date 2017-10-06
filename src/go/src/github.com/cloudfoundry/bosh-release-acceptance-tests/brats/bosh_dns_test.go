package brats_test

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
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

func mustGetLatestDnsVersions() []int {
	session, err := gexec.Start(exec.Command(
		boshBinaryPath, "-n",
		"-d", deploymentName,
		"ssh",
		"-c", "sudo cat /var/vcap/instance/dns/records.json",
	), GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, time.Minute).Should(gexec.Exit(0))

	trimmedOutput := strings.TrimSpace(string(session.Out.Contents()))

	results := extractDnsVersionsList(trimmedOutput)
	Expect(len(results)).To(BeNumerically(">", 0))

	return results
}

var versionSegmentsPattern = regexp.MustCompile(`"version":(\d+)`)

func extractDnsVersionsList(sshContents string) []int {
	matches := versionSegmentsPattern.FindAllStringSubmatch(sshContents, -1)
	Expect(matches).ToNot(BeNil())
	results := make([]int, len(matches))

	for i, match := range matches {
		Expect(len(match)).To(Equal(2))
		value, err := strconv.Atoi(match[1])
		Expect(err).ToNot(HaveOccurred())

		results[i] = value
	}
	return results
}

var _ = Describe("BoshDns", func() {
	var (
		manifestPath              string
		linkedTemplateReleasePath string
	)

	BeforeEach(func() {
		startInnerBosh()

		session, err := gexec.Start(exec.Command(boshBinaryPath, "-n", "upload-stemcell", candidateWardenLinuxStemcellPath), GinkgoWriter, GinkgoWriter)
		Expect(err).ToNot(HaveOccurred())
		Eventually(session, 5*time.Minute).Should(gexec.Exit(0))

		manifestPath, err = filepath.Abs("../assets/dns-with-templates-manifest.yml")
		Expect(err).NotTo(HaveOccurred())

		linkedTemplateReleasePath, err = filepath.Abs("../assets/linked-templates-release")
		Expect(err).NotTo(HaveOccurred())
	})

	AfterEach(stopInnerBosh)

	PContext("having enabled short dns addresses", func() {
		BeforeEach(func() {

			opFilePath, err := filepath.Abs("../assets/op-enable-short-dns-addresses.yml")
			Expect(err).NotTo(HaveOccurred())

			session, err := gexec.Start(exec.Command(
				boshBinaryPath, "deploy",
				"-n",
				"-d", deploymentName,
				manifestPath,
				"-o", opFilePath,
				"-v", fmt.Sprintf("dns-release-path=%s", dnsReleasePath),
				"-v", fmt.Sprintf("linked-template-release-path=%s", linkedTemplateReleasePath),
			), GinkgoWriter, GinkgoWriter)
			Expect(err).ToNot(HaveOccurred())
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
		})

		It("can find instances using the address helper with short names", func() {
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

			matchExpression := regexp.MustCompile(`provider\S+\s+(z1|z2)\s+(\S+)`)
			knownProviders := extractAzIpsMap(matchExpression, string(instanceList))

			session, err = gexec.Start(exec.Command(boshBinaryPath,
				"-d", deploymentName,
				"run-errand", "query-all",
			), GinkgoWriter, GinkgoWriter)
			Expect(err).ToNot(HaveOccurred())
			Eventually(session, time.Minute).Should(gexec.Exit(0))

			Expect(session.Out).To(gbytes.Say("ANSWER: 3"))

			output := string(session.Out.Contents())

			for _, ips := range knownProviders {
				for _, ip := range ips {
					Expect(output).To(MatchRegexp(`q-s0\.g-\d+\.bosh\.\s+\d+\s+IN\s+A\s+%s`, ip))
				}
			}
		})
	})

	Context("When deploying vms across different azs", func() {
		BeforeEach(func() {
			session, err := gexec.Start(exec.Command(
				boshBinaryPath, "deploy",
				"-n",
				"-d", deploymentName,
				manifestPath,
				"-v", fmt.Sprintf("dns-release-path=%s", dnsReleasePath),
				"-v", fmt.Sprintf("linked-template-release-path=%s", linkedTemplateReleasePath),
			), GinkgoWriter, GinkgoWriter)
			Expect(err).ToNot(HaveOccurred())
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
		})

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
				matchExpression := regexp.MustCompile(`provider\S+\s+(z1|z2)\s+(\S+)`)
				knownProviders := extractAzIpsMap(matchExpression, string(instanceList))

				session, err = gexec.Start(exec.Command(boshBinaryPath,
					"-d", deploymentName,
					"run-errand", "query-all",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				Expect(session.Out).To(gbytes.Say("ANSWER: 3"))
				output := string(session.Out.Contents())

				for _, ips := range knownProviders {
					for _, ip := range ips {
						Expect(output).To(ContainSubstring(ip))
					}
				}
			})

			By("finding instances filtering by AZ", func() {
				matchExpression := regexp.MustCompile(`provider\S+\s+(z1)\s+(\S+)`)
				knownProviders := extractAzIpsMap(matchExpression, string(instanceList))

				session, err = gexec.Start(exec.Command(boshBinaryPath,
					"-d", deploymentName,
					"run-errand", "query-with-az-filter",
				), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session, time.Minute).Should(gexec.Exit(0))

				Expect(session.Out).To(gbytes.Say("ANSWER: 2"))
				output := string(session.Out.Contents())

				for _, ips := range knownProviders {
					for _, ip := range ips {
						Expect(output).To(ContainSubstring(ip))
					}
				}
			})
		})

		It("can force a new DNS blob to propagate to ALL vms", func() {
			versionPerInstance := mustGetLatestDnsVersions()
			previousMax := -1
			for _, version := range versionPerInstance {
				if previousMax < version {
					previousMax = version
				}
			}

			session, err := gexec.Start(exec.Command("ssh",
				fmt.Sprintf("%s@%s", innerDirectorUser, innerDirectorIP),
				"-i", innerBoshJumpboxPrivateKeyPath,
				"-oStrictHostKeyChecking=no",
				"sudo /var/vcap/jobs/director/bin/sync_dns_ctl force"),
				GinkgoWriter, GinkgoWriter)
			Expect(err).ToNot(HaveOccurred())
			Eventually(session, 2*time.Minute).Should(gexec.Exit(0))

			newVersionPerInstance := mustGetLatestDnsVersions()
			firstNewVersion := newVersionPerInstance[0]
			Expect(firstNewVersion).To(BeNumerically(">", previousMax))
			for _, version := range newVersionPerInstance {
				Expect(version).To(Equal(firstNewVersion))
			}
		})
	})
})
