package acceptance_test

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

const deploymentName = "dns-with-templates"

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
	session := utils.Bosh("-n", "-d", deploymentName, "ssh",
		"-c", "sudo cat /var/vcap/instance/dns/records.json",
	)
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
		utils.StartInnerBosh()
		utils.UploadStemcell(candidateWardenLinuxStemcellPath)

		manifestPath = utils.AssetPath("dns-with-templates-manifest.yml")
		linkedTemplateReleasePath = filepath.Join(utils.AssetPath("linked-templates-release"), "release.tgz")
	})

	Context("having enabled short dns addresses", func() {
		BeforeEach(func() {
			opFilePath := utils.AssetPath("op-enable-short-dns-addresses.yml")

			session := utils.Bosh("deploy", "-n", "-d", deploymentName, manifestPath,
				"-o", os.Getenv("BOSH_DNS_ADDON_OPS_FILE_PATH"),
				"-o", opFilePath,
				"-v", fmt.Sprintf("dns-release-path=%s", dnsReleasePath),
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
				"-v", fmt.Sprintf("linked-template-release-path=%s", linkedTemplateReleasePath),
				"--vars-store", "creds.yml",
			)
			Eventually(session, 20*time.Minute).Should(gexec.Exit(0))
		})

		It("can find instances using the address helper with short names", func() {
			session := utils.Bosh("-n", "-d", deploymentName, "instances",
				"--column", "instance",
				"--column", "az",
				"--column", "ips",
			)
			Eventually(session, time.Minute).Should(gexec.Exit(0))

			instanceList := session.Out.Contents()

			matchExpression := regexp.MustCompile(`provider\S+\s+(z1|z2)\s+(\S+)`)
			knownProviders := extractAzIpsMap(matchExpression, string(instanceList))

			session = utils.Bosh("-d", deploymentName, "run-errand", "query-all")
			Eventually(session, time.Minute).Should(gexec.Exit(0))

			Expect(session.Out).To(gbytes.Say("ANSWER: 3"))

			output := string(session.Out.Contents())

			for _, ips := range knownProviders {
				for _, ip := range ips {
					Expect(output).To(MatchRegexp(`q-n\d+s0\.q-g\d+\.bosh\.\s+\d+\s+IN\s+A\s+%s`, ip))
				}
			}
		})

		It("can find instances using the address helper with short names by network and instance ID", func() {
			session := utils.Bosh("-n", "-d", deploymentName, "instances",
				"--column", "instance",
				"--column", "az",
				"--column", "ips",
			)
			Eventually(session, time.Minute).Should(gexec.Exit(0))

			instanceList := session.Out.Contents()

			matchExpression := regexp.MustCompile(`provider\S+\s+(z1)\s+(\S+)`)
			knownProviders := extractAzIpsMap(matchExpression, string(instanceList))

			session = utils.Bosh("-d", deploymentName, "run-errand", "query-individual-instance")
			Eventually(session, time.Minute).Should(gexec.Exit(0))

			Expect(session.Out).To(gbytes.Say("ANSWER: 1"))

			output := string(session.Out.Contents())

			ip1 := knownProviders["z1"][0]
			ip2 := knownProviders["z1"][1]
			Expect(output).To(MatchRegexp(`q-m\d+n\d+s\d\.q-g\d+\.bosh\.\s+\d+\s+IN\s+A\s+(%s|%s)`, ip1, ip2))
		})
	})

	Context("When deploying vms across different azs", func() {
		BeforeEach(func() {
			session := utils.Bosh("deploy", "-n", "-d", deploymentName, manifestPath,
				"-o", os.Getenv("BOSH_DNS_ADDON_OPS_FILE_PATH"),
				"-v", fmt.Sprintf("dns-release-path=%s", dnsReleasePath),
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
				"-v", fmt.Sprintf("linked-template-release-path=%s", linkedTemplateReleasePath),
				"--vars-store", "creds.yml",
			)
			Eventually(session, 20*time.Minute).Should(gexec.Exit(0))
		})

		It("can find instances using the address helper", func() {
			session := utils.Bosh("-n", "-d", deploymentName, "instances",
				"--column", "instance",
				"--column", "az",
				"--column", "ips",
			)
			Eventually(session, time.Minute).Should(gexec.Exit(0))

			instanceList := session.Out.Contents()

			By("finding instances in all AZs", func() {
				matchExpression := regexp.MustCompile(`provider\S+\s+(z1|z2)\s+(\S+)`)
				knownProviders := extractAzIpsMap(matchExpression, string(instanceList))

				session = utils.Bosh("-d", deploymentName, "run-errand", "query-all")
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

				session = utils.Bosh("-d", deploymentName, "run-errand", "query-with-az-filter")
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

			session := utils.OuterBosh(
				"-d",
				utils.InnerBoshDirectorName(),
				"ssh",
				"-c",
				"sudo /var/vcap/jobs/director/bin/trigger-one-time-sync-dns",
			)
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
