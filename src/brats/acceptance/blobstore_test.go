package acceptance_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

var _ = Describe("Blobstore", func() {
	Context("SSL", func() {
		testDeployment := func(allowHttp bool, schema string, errorCode int) {
			By(fmt.Sprintf("specifying blobstore.allow_http (%v) and agent.env.bosh.blobstores (%v)", allowHttp, schema))
			utils.StartInnerBosh(
				fmt.Sprintf("-o %s", utils.AssetPath("op-blobstore-https.yml")),
				fmt.Sprintf("-v allow_http=%t", allowHttp),
				fmt.Sprintf("-v agent_blobstore_endpoint=%s://%s:25250", schema, utils.InnerDirectorIP()),
			)

			utils.UploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")
			utils.UploadStemcell(candidateWardenLinuxStemcellPath)

			session := utils.Bosh("-n", "deploy", utils.AssetPath("syslog-manifest.yml"),
				"-d", "syslog-deployment",
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
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
			jqSession, err := gexec.Start(jq, io.Discard, io.Discard)
			Expect(err).ToNot(HaveOccurred())
			_, err = io.Copy(si, bytes.NewReader(boshCmdOutput))
			Expect(err).ToNot(HaveOccurred())
			si.Close()
			Eventually(jqSession, 5*time.Second).Should(gexec.Exit(0))
			return jqSession.Out.Contents()
		}

		getCredentials := func(filepath string) (string, string) {
			session := utils.BoshQuiet(
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
			err := json.Unmarshal(getStdout(session.Out.Contents()), &c)
			Expect(err).ToNot(HaveOccurred())
			return c.Env.AgentEnv.BlobstoresConfig[0].Options.Password,
				c.Env.AgentEnv.BlobstoresConfig[0].Options.User
		}

		It("Uses signed URLs with a stemcell that supports it", func() {
			utils.StartInnerBosh(
				fmt.Sprintf("-o %s", utils.BoshDeploymentAssetPath("enable-signed-urls.yml")),
				fmt.Sprintf("-o %s", utils.AssetPath("ops-enable-signed-urls-cpi.yml")),
			)
			utils.UploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")
			utils.UploadStemcell(candidateWardenLinuxStemcellPath)

			By("compiling (by deploying)")
			session := utils.Bosh("-n", "deploy", utils.AssetPath("syslog-manifest.yml"),
				"-d", "syslog-deployment",
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
			)
			Eventually(session, 10*time.Minute).Should(gexec.Exit(0))

			By("ensuring that credentials are not on disk")

			blobstoreUser, blobstorePassword := getCredentials("/var/vcap/bosh/settings.json")
			Expect(blobstoreUser).To(Equal(""))
			Expect(blobstorePassword).To(Equal(""))

			blobstoreUser, blobstorePassword = getCredentials("/var/vcap/bosh/warden-cpi-agent-env.json")
			Expect(blobstoreUser).To(Equal(""))
			Expect(blobstorePassword).To(Equal(""))

			By("fetch logs")
			session = utils.BoshQuiet("-d", "syslog-deployment", "logs")
			Eventually(session, 30*time.Second).Should(gexec.Exit(0))

			By("validating records.json are updated")
			session = utils.BoshQuiet("-d", "syslog-deployment", "ssh", "syslog_forwarder/0", "-r", "--json", "-c", "sudo cat /var/vcap/instance/dns/records.json")
			Eventually(session, 30*time.Second).Should(gexec.Exit(0))
			records := getStdout(session.Out.Contents())
			Expect(records).To(MatchRegexp("syslog-forwarder")) // presence of anything is shows it has been updated
		})

		// This test is documenting existing non-ideal behavior: if there is a CPI change, this does not
		//  trigger jobs to be recreated. With signed urls, we must update the CPI job and remove blobstore
		//  creds. Operators then must recreate VMs for the new CPI configuration to take into effect. A
		//  normal "bosh deploy" will not converge to the new CPI configuration
		// Contrasted with removing the blobstore creds from the agent env. A normal "bosh deploy" will
		//  cause bosh-director to converge to the new agent env configuration.
		It("Does not strip blobstore credentials from VMs when only the CPI config changes", func() {
			utils.StartInnerBosh(
				fmt.Sprintf("-o %s", utils.BoshDeploymentAssetPath("enable-signed-urls.yml")),
			)
			utils.UploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")
			utils.UploadStemcell(candidateWardenLinuxStemcellPath)

			By("compiling (by deploying)")
			session := utils.Bosh("-n", "deploy", utils.AssetPath("syslog-manifest.yml"),
				"-d", "syslog-deployment",
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
			)
			Eventually(session, 10*time.Minute).Should(gexec.Exit(0))

			utils.StartInnerBosh(
				fmt.Sprintf("-o %s", utils.BoshDeploymentAssetPath("enable-signed-urls.yml")),
				fmt.Sprintf("-o %s", utils.AssetPath("ops-enable-signed-urls-cpi.yml")),
			)
			session = utils.Bosh("-n", "deploy", utils.AssetPath("syslog-manifest.yml"),
				"-d", "syslog-deployment",
				"-v", fmt.Sprintf("stemcell-os=%s", utils.StemcellOS()),
			)
			Eventually(session, 10*time.Minute).Should(gexec.Exit(0))

			By("ensuring that expected credentials are on disk")
			session = utils.BoshQuiet("-d", "syslog-deployment", "ssh", "syslog_forwarder/0", "-r", "--json", "-c", "sudo cat /var/vcap/bosh/settings.json")
			Eventually(session, 30*time.Second).Should(gexec.Exit(0))
			c := config{}
			err := json.Unmarshal(getStdout(session.Out.Contents()), &c)
			Expect(err).ToNot(HaveOccurred())
			fmt.Printf("%+v\n", c)
			Expect(c.Env.AgentEnv.BlobstoresConfig[0].Options.Password).To(Equal(""))
			Expect(c.Env.AgentEnv.BlobstoresConfig[0].Options.User).To(Equal(""))

			session = utils.BoshQuiet("-d", "syslog-deployment", "ssh", "syslog_forwarder/0", "-r", "--json", "-c", "sudo cat /var/vcap/bosh/warden-cpi-agent-env.json")
			Eventually(session, 30*time.Second).Should(gexec.Exit(0))
			c = config{}
			err = json.Unmarshal(getStdout(session.Out.Contents()), &c)
			Expect(err).ToNot(HaveOccurred())
			fmt.Printf("%+v\n", c)
			Expect(c.Env.AgentEnv.BlobstoresConfig[0].Options.Password).To(Equal(""))
			Expect(c.Env.AgentEnv.BlobstoresConfig[0].Options.User).To(Equal(""))
		})
	})

	Context("Access Log", func() {
		var tempBlobstoreDir string

		BeforeEach(func() {
			utils.StartInnerBosh()

			var err error
			tempBlobstoreDir, err = os.MkdirTemp(os.TempDir(), "blobstore_access")
			Expect(err).ToNot(HaveOccurred())

			utils.UploadRelease(boshRelease)

			session := utils.OuterBosh("-d", utils.InnerBoshDirectorName(), "scp", fmt.Sprintf("bosh:%s", BlobstoreAccessLog), tempBlobstoreDir)
			Eventually(session, time.Minute).Should(gexec.Exit(0))
		})

		It("Should log in correct format", func() {
			accessContent, err := os.ReadFile(filepath.Join(tempBlobstoreDir, "blobstore_access.log"))
			Expect(err).ToNot(HaveOccurred())
			Expect(string(accessContent)).To(ContainSubstring("CEF:0|CloudFoundry|BOSH|-|blobstore_api|"))
		})
	})
})
