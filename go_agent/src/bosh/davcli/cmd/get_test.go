package cmd_test

import (
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/davcli/cmd"
	testcmd "bosh/davcli/cmd/testing"
	davconf "bosh/davcli/config"
)

func runGet(config davconf.Config, args []string) (err error) {
	factory := NewFactory()
	factory.SetConfig(config)
	cmd, _ := factory.Create("get")
	return cmd.Run(args)
}

func getFileContent(path string) (content string) {
	file, _ := os.Open(path)
	fileBytes, _ := ioutil.ReadAll(file)
	content = string(fileBytes)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("get run with valid args", func() {
			requestedBlob := "0ca907f2-dde8-4413-a304-9076c9d0978b"
			targetFilePath := filepath.Join(os.TempDir(), "testRunGetCommand.txt")
			defer os.RemoveAll(targetFilePath)

			handler := func(w http.ResponseWriter, r *http.Request) {
				req := testcmd.NewHttpRequest(r)

				username, password, err := req.ExtractBasicAuth()

				Expect(err).ToNot(HaveOccurred())
				Expect(req.URL.Path).To(Equal("/0d/" + requestedBlob))
				Expect(req.Method).To(Equal("GET"))
				Expect(username).To(Equal("some user"))
				Expect(password).To(Equal("some pwd"))

				w.Write([]byte("this is your blob"))
			}

			ts := httptest.NewServer(http.HandlerFunc(handler))
			defer ts.Close()

			config := davconf.Config{
				User:     "some user",
				Password: "some pwd",
				Endpoint: ts.URL,
			}

			err := runGet(config, []string{requestedBlob, targetFilePath})
			Expect(err).ToNot(HaveOccurred())
			Expect(getFileContent(targetFilePath)).To(Equal("this is your blob"))
		})
		It("get run with incorrect arg count", func() {

			config := davconf.Config{}
			err := runGet(config, []string{})

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("Incorrect usage"))
		})
	})
}
