package cmd_test

import (
	. "bosh/davcli/cmd"
	testcmd "bosh/davcli/cmd/testing"
	davconf "bosh/davcli/config"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
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

				assert.NoError(GinkgoT(), err)
				assert.Equal(GinkgoT(), req.URL.Path, "/0d/"+requestedBlob)
				assert.Equal(GinkgoT(), req.Method, "GET")
				assert.Equal(GinkgoT(), username, "some user")
				assert.Equal(GinkgoT(), password, "some pwd")

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
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), getFileContent(targetFilePath), "this is your blob")
		})
		It("get run with incorrect arg count", func() {

			config := davconf.Config{}
			err := runGet(config, []string{})

			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "Incorrect usage")
		})
	})
}
