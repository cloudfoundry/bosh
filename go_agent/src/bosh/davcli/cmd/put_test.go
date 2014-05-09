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
				req := testcmd.NewHTTPRequest(r)

				username, password, err := req.ExtractBasicAuth()

				Expect(err).ToNot(HaveOccurred())
				Expect(req.URL.Path).To(Equal("/d1/" + targetBlob))
				Expect(req.Method).To(Equal("PUT"))
				Expect(username).To(Equal("some user"))
				Expect(password).To(Equal("some pwd"))

				expectedBytes := fileBytes(sourceFilePath)
				actualBytes, _ := ioutil.ReadAll(r.Body)
				Expect(expectedBytes).To(Equal(actualBytes))

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
			Expect(err).ToNot(HaveOccurred())
			Expect(serverWasHit).To(BeTrue())
		})
		It("put run with incorrect arg count", func() {

			config := davconf.Config{}
			err := runPut(config, []string{})

			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("Incorrect usage"))
		})
	})
}
