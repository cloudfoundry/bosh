package brats_test

import (
	"io/ioutil"
	"os"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"fmt"
	"testing"

	"os/exec"
	"time"

	"path/filepath"

	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

const BLOBSTORE_ACCESS_LOG = "/var/vcap/sys/log/blobstore/blobstore_access.log"

func TestBrats(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Brats Suite")
}

var (
	outerBoshBinaryPath,
	boshBinaryPath,
	innerBoshPath,
	innerBoshJumpboxPrivateKeyPath,
	bbrBinaryPath,
	innerDirectorIP,
	boshRelease,
	directorBackupName,
	innerDirectorUser,
	deploymentName,
	boshDirectorReleasePath,
	candidateWardenLinuxStemcellPath,
	stemcellOS,
	dnsReleasePath string
)

var _ = BeforeSuite(func() {
	outerBoshBinaryPath = assertEnvExists("BOSH_BINARY_PATH")

	deploymentName = "dns-with-templates"
	directorBackupName = "director-backup"
	innerDirectorUser = "jumpbox"
	innerBoshPath = "/tmp/inner-bosh/director/"
	boshBinaryPath = filepath.Join(innerBoshPath, "bosh")
	innerBoshJumpboxPrivateKeyPath = filepath.Join(innerBoshPath, "jumpbox_private_key.pem")
	bbrBinaryPath = assertEnvExists("BBR_BINARY_PATH")
	boshRelease = assertEnvExists("BOSH_RELEASE")
	innerDirectorIP = "10.245.0.34"
	dnsReleasePath = assertEnvExists("DNS_RELEASE_PATH")
	boshDirectorReleasePath = assertEnvExists("BOSH_DIRECTOR_RELEASE_PATH")
	candidateWardenLinuxStemcellPath = assertEnvExists("CANDIDATE_STEMCELL_TARBALL_PATH")
	stemcellOS = assertEnvExists("STEMCELL_OS")

	assertEnvExists("BOSH_ENVIRONMENT")
	assertEnvExists("BOSH_DEPLOYMENT_PATH")
})

var _ = AfterSuite(func() {
	session, err := gexec.Start(exec.Command(outerBoshBinaryPath, "-n", "clean-up", "--all"), GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, time.Minute).Should(gexec.Exit(0))
})

func assertEnvExists(envName string) string {
	val, found := os.LookupEnv(envName)
	if !found {
		Fail(fmt.Sprintf("Expected %s", envName))
	}
	return val
}

func startInnerBosh(args ...string) {
	startInnerBoshWithExpectation(false, "", args...)
}

func startInnerBoshWithExpectation(expectedFailure bool, expectedErrorToMatch string, args ...string) {
	effectiveArgs := args
	if stemcellOS == "ubuntu-xenial" {
		effectiveArgs = append(args, "-o", assetPath("inner-bosh-xenial-ops.yml"))
	}

	cmd := exec.Command(fmt.Sprintf("../../../../../../../ci/docker/main-bosh-docker/start-inner-bosh.sh"), effectiveArgs...)
	cmd.Env = os.Environ()
	cmd.Env = append(cmd.Env, fmt.Sprintf("bosh_release_path=%s", boshDirectorReleasePath))

	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())

	if expectedFailure {
		Eventually(session, 25*time.Minute).Should(gbytes.Say(expectedErrorToMatch))
		Eventually(session, 25*time.Minute).Should(gexec.Exit(1))
	} else {
		Eventually(session, 25*time.Minute).Should(gexec.Exit(0))
	}
}

func stopInnerBosh() {
	session, err := gexec.Start(exec.Command("../../../../../../../ci/docker/main-bosh-docker/destroy-inner-bosh.sh"), GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
}

func assetPath(filename string) string {
	path, err := filepath.Abs("../assets/" + filename)
	Expect(err).ToNot(HaveOccurred())

	return path
}

func boshDeploymentAssetPath(assetPath string) string {
	return filepath.Join(os.Getenv("BOSH_DEPLOYMENT_PATH"), assetPath)
}

func execCommand(binaryPath string, args ...string) *gexec.Session {
	session, err := gexec.Start(
		exec.Command(binaryPath, args...),
		GinkgoWriter,
		GinkgoWriter,
	)

	Expect(err).ToNot(HaveOccurred())

	return session
}

func bbr(args ...string) *gexec.Session {
	return execCommand(bbrBinaryPath, args...)
}

func outerBosh(args ...string) *gexec.Session {
	return execCommand(outerBoshBinaryPath, args...)
}

func bosh(args ...string) *gexec.Session {
	return execCommand(boshBinaryPath, args...)
}

func uploadStemcell(stemcellUrl string) {
	session := bosh("-n", "upload-stemcell", stemcellUrl)
	Eventually(session, 5*time.Minute).Should(gexec.Exit(0))
}

func uploadRelease(releaseUrl string) {
	session := bosh("-n", "upload-release", releaseUrl)
	Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
}

type ExternalDBConfig struct {
	Host     string
	User     string
	Password string
	DBName   string

	CACertPath     string
	ClientCertPath string
	ClientKeyPath  string

	ConnectionVarFile     string
	ConnectionOptionsFile string
}

func loadExternalDBConfig(databaseType string, mutualTLSEnabled bool, tmpCertDir string) ExternalDBConfig {
	config := ExternalDBConfig{
		Host:                  assertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_HOST", strings.ToUpper(databaseType))),
		User:                  assertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_USER", strings.ToUpper(databaseType))),
		Password:              assertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_PASSWORD", strings.ToUpper(databaseType))),
		DBName:                assertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_NAME", strings.ToUpper(databaseType))),
		ConnectionVarFile:     fmt.Sprintf("external_db/%s.yml", databaseType),
		ConnectionOptionsFile: fmt.Sprintf("external_db/%s_connection_options.yml", databaseType),
	}

	caContents, err := exec.Command(outerBoshBinaryPath, "int", assetPath(config.ConnectionVarFile), "--path", "/db_ca").Output()
	Expect(err).ToNot(HaveOccurred())
	caFile, err := ioutil.TempFile(tmpCertDir, "db_ca")
	Expect(err).ToNot(HaveOccurred())

	defer caFile.Close()
	_, err = caFile.Write(caContents)
	Expect(err).ToNot(HaveOccurred())

	config.CACertPath = caFile.Name()

	if mutualTLSEnabled {
		clientCertContents := assertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_CLIENT_CERTIFICATE", strings.ToUpper(databaseType)))
		clientKeyContents := assertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_CLIENT_PRIVATE_KEY", strings.ToUpper(databaseType)))

		clientCertFile, err := ioutil.TempFile(tmpCertDir, "client_cert")
		Expect(err).ToNot(HaveOccurred())

		defer clientCertFile.Close()
		_, err = clientCertFile.Write([]byte(clientCertContents))
		Expect(err).ToNot(HaveOccurred())

		clientKeyFile, err := ioutil.TempFile(tmpCertDir, "client_key")
		Expect(err).ToNot(HaveOccurred())

		defer clientKeyFile.Close()
		_, err = clientKeyFile.Write([]byte(clientKeyContents))
		Expect(err).ToNot(HaveOccurred())

		config.ClientCertPath = clientCertFile.Name()
		config.ClientKeyPath = clientKeyFile.Name()
	}

	return config
}

func cleanupMysqlDB(dbConfig ExternalDBConfig) {
	args := []string{
		"-h",
		dbConfig.Host,
		fmt.Sprintf("--user=%s", dbConfig.User),
		fmt.Sprintf("--password=%s", dbConfig.Password),
		"-e",
		fmt.Sprintf("drop database %s; create database %s;", dbConfig.DBName, dbConfig.DBName),
		fmt.Sprintf("--ssl-ca=%s", dbConfig.CACertPath),
	}

	if dbConfig.ClientCertPath != "" || dbConfig.ClientKeyPath != "" {
		args = append(args,
			fmt.Sprintf("--ssl-cert=%s", dbConfig.ClientCertPath),
			fmt.Sprintf("--ssl-key=%s", dbConfig.ClientKeyPath),
			"--ssl-mode=VERIFY_CA",
		)
	} else {
		args = append(args, "--ssl-mode=VERIFY_IDENTITY")
	}

	session := execCommand("mysql", args...)
	Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
}

func innerBoshWithExternalDBOptions(dbConfig ExternalDBConfig) []string {
	options := []string{
		"-o", boshDeploymentAssetPath("misc/external-db.yml"),
		"-o", boshDeploymentAssetPath("experimental/db-enable-tls.yml"),
		"-o", assetPath(dbConfig.ConnectionOptionsFile),
		"--vars-file", assetPath(dbConfig.ConnectionVarFile),
		"-v", fmt.Sprintf("external_db_host=%s", dbConfig.Host),
		"-v", fmt.Sprintf("external_db_user=%s", dbConfig.User),
		"-v", fmt.Sprintf("external_db_password=%s", dbConfig.Password),
		"-v", fmt.Sprintf("external_db_name=%s", dbConfig.DBName),
	}

	if dbConfig.ClientCertPath != "" || dbConfig.ClientKeyPath != "" {
		options = append(options,
			fmt.Sprintf("-o %s", boshDeploymentAssetPath("experimental/db-enable-mutual-tls.yml")),
			fmt.Sprintf("--var-file=db_client_certificate=%s", dbConfig.ClientCertPath),
			fmt.Sprintf("--var-file=db_client_private_key=%s", dbConfig.ClientKeyPath),
		)
	}

	return options
}
