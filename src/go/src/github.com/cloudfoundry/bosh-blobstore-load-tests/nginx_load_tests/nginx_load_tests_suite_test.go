package nginx_load_tests

import (
	"os"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"fmt"
	"testing"
	"io/ioutil"
)

func TestBrats(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Brats Suite")
}

var directorIp, davcliPath, agentPassword string

var _ = BeforeSuite(func() {
	directorIp = assertEnvExists("BOSH_DIRECTOR_IP")
	davcliPath = assertEnvExists("DAVCLI_PATH")
	agentPassword = assertEnvExists("AGENT_PASSWORD")
})

func assertEnvExists(envName string) string {
	val, found := os.LookupEnv(envName)
	if !found {
		Fail(fmt.Sprintf("Expected %s", envName))
	}

	return val
}

func writeTempFile(data []byte, fileName string) string {
	file, err := ioutil.TempFile("/tmp", fileName)
	Expect(err).ToNot(HaveOccurred())

	err = ioutil.WriteFile(file.Name(), data, 0700)
	Expect(err).ToNot(HaveOccurred())

	return file.Name()
}
