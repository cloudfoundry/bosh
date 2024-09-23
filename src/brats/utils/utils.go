package utils

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

const (
	mysqlDBType    = "mysql"
	postgresDBType = "postgres"
)

func repoRoot() string {
	return filepath.Join("..", "..", "..")
}

type ExternalDBConfig struct {
	Host     string
	Type     string
	User     string
	Password string
	DBName   string

	CACertPath     string
	ClientCertPath string
	ClientKeyPath  string

	ConnectionVarFile     string
	ConnectionOptionsFile string
}

var (
	outerBoshBinaryPath,
	boshBinaryPath,
	innerBoshPath,
	innerBoshJumpboxPrivateKeyPath,
	innerDirectorIP,
	innerDirectorUser,
	boshDirectorReleasePath,
	stemcellOS string
)

func Bootstrap() {
	outerBoshBinaryPath = AssertEnvExists("BOSH_BINARY_PATH")

	innerDirectorUser = "jumpbox"
	innerBoshPath = fmt.Sprintf("/tmp/inner-bosh/director/%d", GinkgoParallelProcess())
	boshBinaryPath = filepath.Join(innerBoshPath, "bosh")
	innerBoshJumpboxPrivateKeyPath = filepath.Join(innerBoshPath, "jumpbox_private_key.pem")
	innerDirectorIP = fmt.Sprintf("10.245.0.%d", 10+GinkgoParallelProcess())
	boshDirectorReleasePath = AssertEnvExists("BOSH_DIRECTOR_RELEASE_PATH")
	stemcellOS = AssertEnvExists("STEMCELL_OS")

	AssertEnvExists("BOSH_ENVIRONMENT")
	AssertEnvExists("BOSH_DEPLOYMENT_PATH")
}

func LoadExternalDBConfig(iaasAndDbName string, mutualTLSEnabled bool, tmpCertDir string) *ExternalDBConfig {
	var databaseType string
	if strings.HasSuffix(iaasAndDbName, mysqlDBType) {
		databaseType = mysqlDBType
	} else {
		databaseType = postgresDBType
	}

	config := ExternalDBConfig{
		Type:                  databaseType,
		Host:                  AssertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_HOST", strings.ToUpper(iaasAndDbName))),
		User:                  AssertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_USER", strings.ToUpper(iaasAndDbName))),
		Password:              AssertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_PASSWORD", strings.ToUpper(iaasAndDbName))),
		DBName:                fmt.Sprintf("db_%s_%d", databaseType, GinkgoParallelProcess()),
		ConnectionVarFile:     fmt.Sprintf("external_db/%s.yml", iaasAndDbName),
		ConnectionOptionsFile: fmt.Sprintf("external_db/%s_connection_options.yml", iaasAndDbName),
	}

	caContents := []byte(os.Getenv(fmt.Sprintf("%s_EXTERNAL_DB_CA", strings.ToUpper(iaasAndDbName))))
	if len(caContents) == 0 {
		var err error
		caContents, err = exec.Command(outerBoshBinaryPath, "int", AssetPath(config.ConnectionVarFile), "--path", "/db_ca").Output()
		Expect(err).ToNot(HaveOccurred())
	}
	caFile, err := os.CreateTemp(tmpCertDir, "db_ca")
	Expect(err).ToNot(HaveOccurred())

	defer caFile.Close()
	_, err = caFile.Write(caContents)
	Expect(err).ToNot(HaveOccurred())

	config.CACertPath = caFile.Name()

	if mutualTLSEnabled {
		clientCertContents := AssertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_CLIENT_CERTIFICATE", strings.ToUpper(iaasAndDbName)))
		clientKeyContents := AssertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_CLIENT_PRIVATE_KEY", strings.ToUpper(iaasAndDbName)))

		var clientCertFile *os.File
		clientCertFile, err = os.CreateTemp(tmpCertDir, "client_cert")
		Expect(err).ToNot(HaveOccurred())

		defer clientCertFile.Close()
		_, err = clientCertFile.Write([]byte(clientCertContents))
		Expect(err).ToNot(HaveOccurred())

		var clientKeyFile *os.File
		clientKeyFile, err = os.CreateTemp(tmpCertDir, "client_key")
		Expect(err).ToNot(HaveOccurred())

		defer clientKeyFile.Close()
		_, err = clientKeyFile.Write([]byte(clientKeyContents))
		Expect(err).ToNot(HaveOccurred())

		config.ClientCertPath = clientCertFile.Name()
		config.ClientKeyPath = clientKeyFile.Name()
	}

	return &config
}

func MetricsServerHTTPClient() *http.Client {
	cmd := exec.Command("bosh", "int", filepath.Join(innerBoshPath, "creds.yml"), "--path", "/metrics_server_client_tls/ca")
	caCertificateData, err := cmd.Output()
	Expect(err).NotTo(HaveOccurred())

	caCertPool := x509.NewCertPool()
	if ok := caCertPool.AppendCertsFromPEM(caCertificateData); !ok {
		Fail("Failed to load CA certificate for metrics server")
	}

	cmd = exec.Command("bosh", "int", filepath.Join(innerBoshPath, "creds.yml"), "--path", "/metrics_server_client_tls/certificate")
	certificateData, err := cmd.Output()
	Expect(err).NotTo(HaveOccurred())

	cmd = exec.Command("bosh", "int", filepath.Join(innerBoshPath, "creds.yml"), "--path", "/metrics_server_client_tls/private_key")
	privateKeyData, err := cmd.Output()
	Expect(err).NotTo(HaveOccurred())

	certificate, err := tls.X509KeyPair(certificateData, privateKeyData)
	Expect(err).NotTo(HaveOccurred())

	tlsConfig := &tls.Config{
		MinVersion:   tls.VersionTLS12,
		RootCAs:      caCertPool,
		Certificates: []tls.Certificate{certificate},
		CipherSuites: []uint16{
			tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
			tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
		},
	}

	httpTransport := &http.Transport{TLSClientConfig: tlsConfig}

	return &http.Client{Transport: httpTransport}
}

func DeleteDB(dbConfig *ExternalDBConfig) {
	if dbConfig == nil {
		return
	}

	if dbConfig.Type == mysqlDBType {
		deleteMySQL(dbConfig)
	} else if dbConfig.Type == postgresDBType {
		deletePostgres(dbConfig)
	}
}

func deleteMySQL(dbConfig *ExternalDBConfig) {
	args := []string{
		"-h",
		dbConfig.Host,
		fmt.Sprintf("--user=%s", dbConfig.User),
		fmt.Sprintf("--password=%s", dbConfig.Password),
		"-e",
		fmt.Sprintf("drop database if exists %s;", dbConfig.DBName),
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

	session := ExecCommand(mysqlDBType, args...)
	Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
}

func deletePostgres(dbConfig *ExternalDBConfig) {
	connstring := fmt.Sprintf("dbname=postgres host=%s user=%s password=%s sslrootcert=%s ",
		dbConfig.Host,
		dbConfig.User,
		dbConfig.Password,
		dbConfig.CACertPath,
	)

	if dbConfig.ClientCertPath != "" || dbConfig.ClientKeyPath != "" {
		connstring += fmt.Sprintf("sslcert=%s sslkey=%s sslmode=verify-ca ",
			dbConfig.ClientCertPath,
			dbConfig.ClientKeyPath,
		)
	} else {
		connstring += "sslmode=verify-full "
	}

	args := []string{
		connstring,
		"-c",
		fmt.Sprintf("drop database if exists %s;", dbConfig.DBName),
	}

	session := ExecCommand("psql", args...)
	Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
}

func CreateDB(dbConfig *ExternalDBConfig) {
	if dbConfig == nil {
		return
	}

	if dbConfig.Type == mysqlDBType {
		createMySQL(dbConfig)
	} else if dbConfig.Type == postgresDBType {
		createPostgres(dbConfig)
	}
}

func createMySQL(dbConfig *ExternalDBConfig) {
	args := []string{
		"-h",
		dbConfig.Host,
		fmt.Sprintf("--user=%s", dbConfig.User),
		fmt.Sprintf("--password=%s", dbConfig.Password),
		"-e",
		fmt.Sprintf("drop database if exists %s; create database %s;", dbConfig.DBName, dbConfig.DBName),
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

	session := ExecCommand(mysqlDBType, args...)
	Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
}

func createPostgres(dbConfig *ExternalDBConfig) {
	connstring := fmt.Sprintf("dbname=postgres host=%s user=%s password=%s sslrootcert=%s ",
		dbConfig.Host,
		dbConfig.User,
		dbConfig.Password,
		dbConfig.CACertPath,
	)

	if dbConfig.ClientCertPath != "" || dbConfig.ClientKeyPath != "" {
		connstring += fmt.Sprintf("sslcert=%s sslkey=%s sslmode=verify-ca ",
			dbConfig.ClientCertPath,
			dbConfig.ClientKeyPath,
		)
	} else {
		connstring += "sslmode=verify-full "
	}

	args := []string{
		connstring,
		"-c",
		fmt.Sprintf("drop database if exists %s;", dbConfig.DBName),
	}

	session := ExecCommand("psql", args...)
	Eventually(session, 2*time.Minute).Should(gexec.Exit(0))

	args = []string{
		connstring,
		"-c",
		fmt.Sprintf("create database %s;", dbConfig.DBName),
	}

	session = ExecCommand("psql", args...)
	Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
}

func AssertEnvExists(envName string) string {
	val, found := os.LookupEnv(envName)
	if !found {
		Fail(fmt.Sprintf("Expected %s", envName))
	}
	return val
}

func AssetPath(filename string) string {
	path, err := filepath.Abs("../assets/" + filename)
	Expect(err).ToNot(HaveOccurred())

	return path
}

func ExecCommand(binaryPath string, args ...string) *gexec.Session {
	return execCommand(GinkgoWriter, GinkgoWriter, binaryPath, args...)
}

func ExecCommandQuiet(binaryPath string, args ...string) *gexec.Session {
	return execCommand(io.Discard, io.Discard, binaryPath, args...)
}

func execCommand(stdout, stderr io.Writer, binaryPath string, args ...string) *gexec.Session {
	session, err := gexec.Start(
		exec.Command(binaryPath, args...),
		stdout,
		stderr,
	)

	Expect(err).ToNot(HaveOccurred())

	return session
}

func StartInnerBosh(args ...string) {
	StartInnerBoshWithExpectation(false, "", args...)
}

func StartInnerBoshWithExpectation(expectedFailure bool, expectedErrorToMatch string, args ...string) {
	effectiveArgs := []string{strconv.Itoa(GinkgoParallelProcess())}
	effectiveArgs = append(effectiveArgs, args...)

	cmd := exec.Command(
		filepath.Join(repoRoot(), "ci", "dockerfiles", "docker-cpi", "start-inner-bosh-parallel.sh"),
		effectiveArgs...,
	)
	cmd.Env = os.Environ()

	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())

	if expectedFailure {
		Eventually(session, 25*time.Minute).Should(gbytes.Say(expectedErrorToMatch))
		Eventually(session, 25*time.Minute).Should(gexec.Exit(1))
	} else {
		Eventually(session, 25*time.Minute).Should(gexec.Exit(0))
	}
}

func CreateAndUploadBOSHRelease() {
	cmd := exec.Command(
		filepath.Join(repoRoot(), "ci", "dockerfiles", "docker-cpi", "create-and-upload-release.sh"),
		strconv.Itoa(GinkgoParallelProcess()),
	)
	cmd.Env = os.Environ()
	cmd.Env = append(cmd.Env, fmt.Sprintf("bosh_release_path=%s", boshDirectorReleasePath))

	session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
}

func CreateRelease(path string) {
	session := Bosh("create-release", "--dir", path)
	Eventually(session, 1*time.Minute).Should(gexec.Exit(0))
}

func StopInnerBosh() {
	session, err := gexec.Start(
		exec.Command(
			filepath.Join(repoRoot(), "ci", "dockerfiles", "docker-cpi", "destroy-inner-bosh.sh"),
			strconv.Itoa(GinkgoParallelProcess()),
		),
		GinkgoWriter,
		GinkgoWriter,
	)
	Expect(err).ToNot(HaveOccurred())
	Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
}

func InnerBoshExists() bool {
	// If the inner BOSH has not been started, then the BOSH helper script will
	// not exist.
	_, err := os.Stat(BoshBinaryPath())
	if os.IsNotExist(err) {
		return false
	}
	Expect(err).NotTo(HaveOccurred())
	return true
}

func BoshDeploymentAssetPath(assetPath string) string {
	return filepath.Join(os.Getenv("BOSH_DEPLOYMENT_PATH"), assetPath)
}

func OuterBosh(args ...string) *gexec.Session {
	return ExecCommand(outerBoshBinaryPath, args...)
}

func OuterBoshQuiet(args ...string) *gexec.Session {
	return ExecCommandQuiet(outerBoshBinaryPath, args...)
}

func Bosh(args ...string) *gexec.Session {
	return ExecCommand(boshBinaryPath, args...)
}

func BoshQuiet(args ...string) *gexec.Session {
	return ExecCommandQuiet(boshBinaryPath, args...)
}

func UploadStemcell(stemcellURL string) {
	session := Bosh("-n", "upload-stemcell", stemcellURL)
	Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
}

func UploadRelease(releaseURL string) {
	session := Bosh("-n", "upload-release", releaseURL)
	Eventually(session, 4*time.Minute).Should(gexec.Exit(0))
}

func UploadReleaseDir(releaseDir string) {
	session := Bosh("-n", "upload-release", "--dir", releaseDir)
	Eventually(session, 4*time.Minute).Should(gexec.Exit(0))
}

func InnerBoshDirectorName() string {
	return fmt.Sprintf("bosh-%d", GinkgoParallelProcess())
}

func InnerBoshWithExternalDBOptions(dbConfig *ExternalDBConfig) []string {
	options := []string{
		"-o", BoshDeploymentAssetPath("misc/external-db.yml"),
		"-o", BoshDeploymentAssetPath("experimental/db-enable-tls.yml"),
		"-o", AssetPath(dbConfig.ConnectionOptionsFile),
		"--vars-file", AssetPath(dbConfig.ConnectionVarFile),
		fmt.Sprintf("--var-file=db_ca=%s", dbConfig.CACertPath),
		"-v", fmt.Sprintf("external_db_host=%s", dbConfig.Host),
		"-v", fmt.Sprintf("external_db_user=%s", dbConfig.User),
		"-v", fmt.Sprintf("external_db_password=%s", dbConfig.Password),
		"-v", fmt.Sprintf("external_db_name=%s", dbConfig.DBName),
	}

	if dbConfig.ClientCertPath != "" || dbConfig.ClientKeyPath != "" {
		options = append(options,
			fmt.Sprintf("-o %s", BoshDeploymentAssetPath("experimental/db-enable-mutual-tls.yml")),
			fmt.Sprintf("-o %s", AssetPath("tls-skip-host-verify.yml")),
			fmt.Sprintf("--var-file=db_client_certificate=%s", dbConfig.ClientCertPath),
			fmt.Sprintf("--var-file=db_client_private_key=%s", dbConfig.ClientKeyPath),
		)
	}

	return options
}

func StemcellOS() string                     { return stemcellOS }
func BoshBinaryPath() string                 { return boshBinaryPath }
func OuterBoshBinaryPath() string            { return outerBoshBinaryPath }
func InnerDirectorIP() string                { return innerDirectorIP }
func InnerDirectorUser() string              { return innerDirectorUser }
func InnerBoshJumpboxPrivateKeyPath() string { return innerBoshJumpboxPrivateKeyPath }
