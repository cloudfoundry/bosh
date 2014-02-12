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

func runPut(config davconf.Config, args []string) (err error) {
	factory := NewFactory()
	factory.SetConfig(config)
	cmd, _ := factory.Create("put")
	return cmd.Run(args)
}

func fileBytes(path string) (content []byte) {
	f, _ := os.Open(path)
	content, _ = ioutil.ReadAll(f)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("put run with valid args", func() {
			pwd, _ := os.Getwd()
			sourceFilePath := filepath.Join(pwd, "../../../../fixtures/cat.jpg")
			targetBlob := "some-other-awesome-guid"
			serverWasHit := false

			handler := func(w http.ResponseWriter, r *http.Request) {
				serverWasHit = true
				req := testcmd.NewHttpRequest(r)

				username, password, err := req.ExtractBasicAuth()

				assert.NoError(GinkgoT(), err)
				assert.Equal(GinkgoT(), req.URL.Path, "/d1/"+targetBlob)
				assert.Equal(GinkgoT(), req.Method, "PUT")
				assert.Equal(GinkgoT(), username, "some user")
				assert.Equal(GinkgoT(), password, "some pwd")

				expectedBytes := fileBytes(sourceFilePath)
				actualBytes, _ := ioutil.ReadAll(r.Body)
				assert.Equal(GinkgoT(), expectedBytes, actualBytes)

				w.WriteHeader(200)
			}

			ts := httptest.NewServer(http.HandlerFunc(handler))
			defer ts.Close()

			config := davconf.Config{
				User:     "some user",
				Password: "some pwd",
				Endpoint: ts.URL,
			}

			err := runPut(config, []string{sourceFilePath, targetBlob})
			assert.NoError(GinkgoT(), err)
			assert.True(GinkgoT(), serverWasHit)
		})
		It("put run with incorrect arg count", func() {

			config := davconf.Config{}
			err := runPut(config, []string{})

			assert.Error(GinkgoT(), err)
			assert.Contains(GinkgoT(), err.Error(), "Incorrect usage")
		})
	})
}
