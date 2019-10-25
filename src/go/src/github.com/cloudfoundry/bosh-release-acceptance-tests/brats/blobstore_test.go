package brats_test

import (
	"bytes"
	"encoding/json"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo/extensions/table"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"fmt"
	"time"
)

var _ = Describe("Blobstore", func() {
	Context("SSL", func() {
		testDeployment := func(allowHttp bool, schema string, errorCode int) {
			By(fmt.Sprintf("specifying blobstore.allow_http (%v) and agent.env.bosh.blobstores (%v)", allowHttp, schema))
			bratsutils.StartInnerBosh(
				fmt.Sprintf("-o %s", bratsutils.AssetPath("op-blobstore-https.yml")),
				fmt.Sprintf("-v allow_http=%t", allowHttp),
				fmt.Sprintf("-v agent_blobstore_endpoint=%s://%s:25250", schema, bratsutils.InnerDirectorIP()),
			)

			bratsutils.UploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")
			bratsutils.UploadStemcell(candidateWardenLinuxStemcellPath)

			session := bratsutils.Bosh("-n", "deploy", bratsutils.AssetPath("syslog-manifest.yml"),
				"-d", "syslog-deployment",
				"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
			)
			Eventually(session, 10*time.Minute).Should(gexec.Exit(errorCode))
		}

		DescribeTable("with allow_http true", testDeployment,
			Entry("allows http connections", true, "http", 0),
			Entry("allows https connections", true, "https", 0),
		)

		DescribeTable("with allow_http false", testDeployment,
			Entry("does not allow http connections", false, "http", 1),
			Entry("allows https connections", false, "https", 0),
		)
	})

	Context("When signed URLs are enabled", func() {
		type blobstoreOptions struct {
			Password string `json:"password"`
			User     string `json:"user"`
		}
		type blobstoreConfig struct {
			Options blobstoreOptions `json:"options"`
		}
		type agentEnv struct {
			BlobstoresConfig []blobstoreConfig `json:"blobstores"`
		}
		type env struct {
			AgentEnv agentEnv `json:"bosh"`
		}
		type config struct {
			Env             env             `json:"env"`
			BlobstoreConfig blobstoreConfig `json:"blobstore"`
		}

		getStdout := func(boshCmdOutput []byte) []byte {
			jq := exec.Command("jq", ".Tables[0].Rows[0].stdout", "-r")
			si, err := jq.StdinPipe()
			Expect(err).ToNot(HaveOccurred())
			jqSession, err := gexec.Start(jq, ioutil.Discard, ioutil.Discard)
			Expect(err).ToNot(HaveOccurred())
			io.Copy(si, bytes.NewReader(boshCmdOutput))
			si.Close()
			Eventually(jqSession, 5*time.Second).Should(gexec.Exit(0))
			return jqSession.Out.Contents()
		}

		getCredentials := func(filepath string) (string, string, string, string) {
			session := bratsutils.BoshQuiet(
				"-d",
				"syslog-deployment",
				"ssh",
				"syslog_forwarder/0",
				"-r",
				"--json",
				"-c",
				fmt.Sprintf("sudo cat %s", filepath),
			)
			Eventually(session, 30*time.Second).Should(gexec.Exit(0))
			c := config{}
			json.Unmarshal(getStdout(session.Out.Contents()), &c)
			return c.BlobstoreConfig.Options.User,
				c.BlobstoreConfig.Options.Password,
				c.Env.AgentEnv.BlobstoresConfig[0].Options.Password,
				c.Env.AgentEnv.BlobstoresConfig[0].Options.User
		}

		XIt("Uses signed URLs with a stemcell that supports it", func() {
			bratsutils.StartInnerBosh(
				fmt.Sprintf("-o %s", bratsutils.AssetPath("ops-enable-signed-urls.yml")),
				fmt.Sprintf("-o %s", bratsutils.AssetPath("ops-enable-signed-urls-cpi.yml")),
			)
			bratsutils.UploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")
			bratsutils.UploadStemcell(candidateWardenLinuxStemcellPath)

			By("compiling (by deploying)")
			session := bratsutils.Bosh("-n", "deploy", bratsutils.AssetPath("syslog-manifest.yml"),
				"-d", "syslog-deployment",
				"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
			)
			Eventually(session, 10*time.Minute).Should(gexec.Exit(0))

			By("ensuring that credentials are not on disk")

			cpiBlobstoreUser, cpiBlobstorePassword, blobstoreUser, blobstorePassword := getCredentials("/var/vcap/bosh/settings.json")
			Expect(cpiBlobstoreUser).To(Equal(""))
			Expect(cpiBlobstorePassword).To(Equal(""))
			Expect(blobstoreUser).To(Equal(""))
			Expect(blobstorePassword).To(Equal(""))

			cpiBlobstoreUser, cpiBlobstorePassword, blobstoreUser, blobstorePassword = getCredentials("/var/vcap/bosh/warden-cpi-agent-env.json")
			Expect(cpiBlobstoreUser).To(Equal(""))
			Expect(cpiBlobstorePassword).To(Equal(""))
			Expect(blobstoreUser).To(Equal(""))
			Expect(blobstorePassword).To(Equal(""))

			By("fetch logs")
			session = bratsutils.BoshQuiet("-d", "syslog-deployment", "logs")
			Eventually(session, 30*time.Second).Should(gexec.Exit(0))

			By("validating records.json are updated")
			session = bratsutils.BoshQuiet("-d", "syslog-deployment", "ssh", "syslog_forwarder/0", "-r", "--json", "-c", "sudo cat /var/vcap/instance/dns/records.json")
			Eventually(session, 30*time.Second).Should(gexec.Exit(0))
			records := getStdout(session.Out.Contents())
			Expect(records).To(MatchRegexp("syslog-forwarder")) // presence of anything is shows it has been updated
		})

		It("falls back to agent credentials on a stemcell that does not support signed URLs", func() {
			bratsutils.StartInnerBosh(
				fmt.Sprintf("-o %s", bratsutils.AssetPath("ops-enable-signed-urls.yml")),
			)
			bratsutils.UploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")

			By("uploading a stemcell that does not support signed URLs")
			bratsutils.UploadStemcell("https://bosh-core-stemcells.s3-accelerate.amazonaws.com/456.40/bosh-stemcell-456.40-warden-boshlite-ubuntu-xenial-go_agent.tgz")

			session := bratsutils.Bosh("-n", "deploy", bratsutils.AssetPath("syslog-manifest.yml"),
				"-d", "syslog-deployment",
				"-o", bratsutils.AssetPath("specify-stemcell-version.yml"),
				"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
				"-v", "stemcell-version='456.40'",
			)
			Eventually(session, 10*time.Minute).Should(gexec.Exit(0))

			By("ensuring that credentials are on disk")
			cpiBlobstoreUser, cpiBlobstorePassword, blobstoreUser, blobstorePassword := getCredentials("/var/vcap/bosh/settings.json")
			Expect(cpiBlobstoreUser).NotTo(Equal(""))
			Expect(cpiBlobstorePassword).NotTo(Equal(""))
			Expect(blobstoreUser).NotTo(Equal(""))
			Expect(blobstorePassword).NotTo(Equal(""))

			cpiBlobstoreUser, cpiBlobstorePassword, blobstoreUser, blobstorePassword = getCredentials("/var/vcap/bosh/warden-cpi-agent-env.json")
			Expect(cpiBlobstoreUser).NotTo(Equal(""))
			Expect(cpiBlobstorePassword).NotTo(Equal(""))
			Expect(blobstoreUser).NotTo(Equal(""))
			Expect(blobstorePassword).NotTo(Equal(""))

			By("fetch logs")
			session = bratsutils.BoshQuiet("-d", "syslog-deployment", "logs")
			Eventually(session, 30*time.Second).Should(gexec.Exit(0))

			By("validating records.json are updated")
			session = bratsutils.BoshQuiet("-d", "syslog-deployment", "ssh", "syslog_forwarder/0", "-r", "--json", "-c", "sudo cat /var/vcap/instance/dns/records.json")
			Eventually(session, 30*time.Second).Should(gexec.Exit(0))
			records := getStdout(session.Out.Contents())
			Expect(records).To(MatchRegexp("syslog-forwarder")) // presence of anything is shows it has been updated
		})

		// This test is documenting existing non-ideal behavior; if it were easy to change
		// this then it would not be a problem.
		XIt("Does not strip blobstore credentials from VMs when only the CPI config changes", func() {
			bratsutils.StartInnerBosh(
				fmt.Sprintf("-o %s", bratsutils.AssetPath("ops-enable-signed-urls.yml")),
			)
			bratsutils.UploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")
			bratsutils.UploadStemcell(candidateWardenLinuxStemcellPath)

			By("compiling (by deploying)")
			session := bratsutils.Bosh("-n", "deploy", bratsutils.AssetPath("syslog-manifest.yml"),
				"-d", "syslog-deployment",
				"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
			)
			Eventually(session, 10*time.Minute).Should(gexec.Exit(0))

			bratsutils.StartInnerBosh(
				fmt.Sprintf("-o %s", bratsutils.AssetPath("ops-enable-signed-urls.yml")),
				fmt.Sprintf("-o %s", bratsutils.AssetPath("ops-enable-signed-urls-cpi.yml")),
			)
			session = bratsutils.Bosh("-n", "deploy", bratsutils.AssetPath("syslog-manifest.yml"),
				"-d", "syslog-deployment",
				"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
			)
			Eventually(session, 10*time.Minute).Should(gexec.Exit(0))

			By("ensuring that expected credentials are on disk")
			session = bratsutils.BoshQuiet("-d", "syslog-deployment", "ssh", "syslog_forwarder/0", "-r", "--json", "-c", "sudo cat /var/vcap/bosh/settings.json")
			Eventually(session, 30*time.Second).Should(gexec.Exit(0))
			c := config{}
			json.Unmarshal(getStdout(session.Out.Contents()), &c)
			fmt.Printf("%+v\n", c)
			Expect(c.Env.AgentEnv.BlobstoresConfig[0].Options.Password).To(Equal(""))
			Expect(c.Env.AgentEnv.BlobstoresConfig[0].Options.User).To(Equal(""))

			// Not removed since the CPI config change does not make the VM recreate
			Expect(c.BlobstoreConfig.Options.User).ToNot(Equal(""))
			Expect(c.BlobstoreConfig.Options.Password).ToNot(Equal(""))

			session = bratsutils.BoshQuiet("-d", "syslog-deployment", "ssh", "syslog_forwarder/0", "-r", "--json", "-c", "sudo cat /var/vcap/bosh/warden-cpi-agent-env.json")
			Eventually(session, 30*time.Second).Should(gexec.Exit(0))
			c = config{}
			json.Unmarshal(getStdout(session.Out.Contents()), &c)
			fmt.Printf("%+v\n", c)
			Expect(c.Env.AgentEnv.BlobstoresConfig[0].Options.Password).To(Equal(""))
			Expect(c.Env.AgentEnv.BlobstoresConfig[0].Options.User).To(Equal(""))

			// Not removed since the CPI config change does not make the VM recreate
			Expect(c.BlobstoreConfig.Options.User).ToNot(Equal(""))
			Expect(c.BlobstoreConfig.Options.Password).ToNot(Equal(""))
		})
	})

	Context("Access Log", func() {
		var tempBlobstoreDir string

		BeforeEach(func() {
			bratsutils.StartInnerBosh()

			var err error
			tempBlobstoreDir, err = ioutil.TempDir(os.TempDir(), "blobstore_access")
			Expect(err).ToNot(HaveOccurred())

			bratsutils.UploadRelease(boshRelease)

			session := bratsutils.OuterBosh("-d", bratsutils.InnerBoshDirectorName(), "scp", fmt.Sprintf("bosh:%s", BLOBSTORE_ACCESS_LOG), tempBlobstoreDir)
			Eventually(session, time.Minute).Should(gexec.Exit(0))
		})

		It("Should log in correct format", func() {
			accessContent, err := ioutil.ReadFile(filepath.Join(tempBlobstoreDir, "blobstore_access.log"))
			Expect(err).ToNot(HaveOccurred())
			Expect(string(accessContent)).To(ContainSubstring("CEF:0|CloudFoundry|BOSH|-|blobstore_api|"))
		})
	})
})
